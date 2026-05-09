package main

import "core:fmt"
import "core:strings"

parse_tyx :: proc(input: string) -> ([dynamic]Entry, bool) {
    entries: [dynamic]Entry
    current: []string
    seen_project := false
    lines := strings.split(input, "\n")

    for line, i in lines {
        line_number := i + 1
        trimmed := strings.trim_space(line)
        if trimmed == "" do continue
        if strings.has_prefix(trimmed, "#") do continue

        if has_unclosed_quote(trimmed) {
            fmt.printf("Fix\n  Unterminated quoted token on line %d.\n", line_number)
            return entries, false
        }

        if is_header(trimmed) {
            head := strings.trim_right(trimmed, ":")
            tokens, ok := tokenize(head)
            if !ok {
                fmt.printf("Fix\n  Could not parse header on line %d.\n", line_number)
                return entries, false
            }
            if !validate_header(tokens, line_number, &seen_project) do return entries, false
            current = tokens
            continue
        }

        if len(current) == 0 {
            fmt.printf("Fix\n  Entry before any section on line %d.\n", line_number)
            fmt.println("\n  Add a section header such as `project:` or `tools:` before entries.")
            return entries, false
        }

        tokens, ok := tokenize(trimmed)
        if !ok {
            fmt.printf("Fix\n  Could not parse entry on line %d.\n", line_number)
            return entries, false
        }
        if !validate_entry(current, tokens, line_number) do return entries, false
        append(&entries, Entry{header = current, tokens = tokens, line = line_number})
    }

    if !seen_project {
        fmt.println("Fix")
        fmt.println("  project.tyx is missing the `project:` header.")
        fmt.println("")
        fmt.println("  Add `project:` near the top of the file.")
        return entries, false
    }

    return entries, true
}

validate_header :: proc(tokens: []string, line: int, seen_project: ^bool) -> bool {
    if len(tokens) == 0 {
        fmt.printf("Fix\n  Empty section header on line %d.\n", line)
        return false
    }

    section := tokens[0]
    switch section {
    case "project":
        if len(tokens) != 1 {
            fmt.printf("Fix\n  `project:` does not accept qualifiers on line %d.\n", line)
            return false
        }
        seen_project^ = true
    case "tools", "services", "env":
        if len(tokens) != 1 {
            fmt.printf("Unsupported\n  Qualified `%s` section on line %d is not supported yet.\n", section, line)
            fmt.println("")
            fmt.printf("Fix\n  Use `%s:` without qualifiers for the MVP.\n", section)
            return false
        }
    case "scripts":
        if len(tokens) != 2 {
            fmt.printf("Fix\n  `scripts` section on line %d needs exactly one runner.\n", line)
            fmt.println("")
            fmt.println("  Example: `scripts pnpm:`")
            return false
        }
        if !is_supported_runner(tokens[1]) {
            fmt.printf("Unsupported\n  script runner `%s` on line %d is not supported.\n", tokens[1], line)
            fmt.println("")
            fmt.println("Fix\n  Use npm, pnpm, yarn, bun, or a command available on PATH.")
            return false
        }
    case:
        fmt.printf("Unsupported\n  section `%s` on line %d is not supported.\n", section, line)
        fmt.println("")
        fmt.println("Fix\n  Use project:, tools:, services:, env:, or scripts <runner>:")
        return false
    }

    return true
}

validate_entry :: proc(header, tokens: []string, line: int) -> bool {
    if len(tokens) == 0 do return true

    section := header[0]
    switch section {
    case "project":
        fmt.printf("Fix\n  `project:` does not accept entries; found one on line %d.\n", line)
        return false
    case "tools":
        if len(tokens) != 2 {
            fmt.printf("Fix\n  Tool entry on line %d must be `<tool> <version>`.\n", line)
            fmt.println("")
            fmt.println("  Example: `node 22`")
            return false
        }
        if !is_supported_tool(tokens[0]) {
            fmt.printf("Unsupported\n  tool `%s` on line %d is not supported yet.\n", tokens[0], line)
            fmt.println("")
            fmt.println("Fix\n  Use node, npm, pnpm, yarn, or bun for the MVP.")
            return false
        }
    case "services":
        if len(tokens) != 2 || tokens[0] != "compose" {
            fmt.printf("Fix\n  Service entry on line %d must be `compose <file>`.\n", line)
            fmt.println("")
            fmt.println("  Example: `compose compose.yaml`")
            return false
        }
    case "env":
        if len(tokens) != 2 || (tokens[0] != "example" && tokens[0] != "file") {
            fmt.printf("Fix\n  Env entry on line %d must be `example <file>` or `file <file>`.\n", line)
            return false
        }
    case "scripts":
        if len(tokens) != 1 {
            fmt.printf("Fix\n  Script entry on line %d must be one script name.\n", line)
            fmt.println("\n  Quote names that contain spaces, e.g. `\"dev server\"`.")
            return false
        }
    }

    return true
}

is_supported_tool :: proc(name: string) -> bool {
    return name == "node" || name == "npm" || name == "pnpm" || name == "yarn" || name == "bun"
}

is_supported_runner :: proc(name: string) -> bool {
    // MVP accepts Node package runners and simple command runners used by fixtures.
    return is_supported_tool(name) || name == "echo"
}

has_unclosed_quote :: proc(line: string) -> bool {
    in_quote := false
    escaped := false
    for c in line {
        b := byte(c)
        if escaped {
            escaped = false
            continue
        }
        if b == '\\' && in_quote {
            escaped = true
            continue
        }
        if b == '"' do in_quote = !in_quote
    }
    return in_quote
}

is_header :: proc(line: string) -> bool {
    in_quote := false
    escaped := false
    last_non_space := byte(0)

    for c in line {
        b := byte(c)
        if escaped {
            escaped = false
            last_non_space = b
            continue
        }
        if b == '\\' && in_quote {
            escaped = true
            last_non_space = b
            continue
        }
        if b == '"' do in_quote = !in_quote
        if b != ' ' && b != '\t' do last_non_space = b
    }

    return !in_quote && last_non_space == ':'
}

tokenize :: proc(line: string) -> ([]string, bool) {
    tokens: [dynamic]string
    i := 0

    for i < len(line) {
        for i < len(line) && is_space(line[i]) do i += 1
        if i >= len(line) do break

        if line[i] == '"' {
            i += 1
            b := strings.builder_make()
            for i < len(line) {
                if line[i] == '\\' && i+1 < len(line) {
                    next := line[i+1]
                    if next == '"' || next == '\\' {
                        strings.write_byte(&b, next)
                        i += 2
                        continue
                    }
                }
                if line[i] == '"' do break
                strings.write_byte(&b, line[i])
                i += 1
            }
            if i >= len(line) {
                fmt.println("Fix\n  Unterminated quoted token")
                return tokens[:], false
            }
            append(&tokens, strings.to_string(b))
            i += 1
        } else {
            start := i
            for i < len(line) && !is_space(line[i]) do i += 1
            append(&tokens, line[start:i])
        }
    }

    return tokens[:], true
}

is_space :: proc(b: byte) -> bool {
    return b == ' ' || b == '\t' || b == '\r'
}

config_from_entries :: proc(entries: []Entry) -> Project_Config {
    cfg: Project_Config

    for e in entries {
        if len(e.header) == 0 do continue
        section := e.header[0]

        switch section {
        case "tools":
            append(&cfg.tools, Tool{name = e.tokens[0], version = e.tokens[1]})
        case "services":
            append(&cfg.compose_files, e.tokens[1])
        case "env":
            if e.tokens[0] == "example" do append(&cfg.env_examples, e.tokens[1])
            if e.tokens[0] == "file" do append(&cfg.env_files, e.tokens[1])
        case "scripts":
            add_script(&cfg, e.header[1], e.tokens[0])
        }
    }

    return cfg
}

add_script :: proc(cfg: ^Project_Config, runner, script: string) {
    idx := find_script_group(cfg, runner)
    if idx < 0 {
        group := Script_Group{runner = runner}
        append(&group.scripts, script)
        append(&cfg.script_groups, group)
        return
    }
    append(&cfg.script_groups[idx].scripts, script)
}

find_script_group :: proc(cfg: ^Project_Config, runner: string) -> int {
    for group, i in cfg.script_groups {
        if group.runner == runner do return i
    }
    return -1
}
