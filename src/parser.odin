package main

import "core:fmt"
import "core:strings"

parse_tyx :: proc(input: string) -> ([dynamic]Entry, bool) {
    entries: [dynamic]Entry
    current: []string
    lines := strings.split(input, "\n")

    for line, i in lines {
        trimmed := strings.trim_space(line)
        if trimmed == "" do continue
        if strings.has_prefix(trimmed, "#") do continue

        if is_header(trimmed) {
            head := strings.trim_right(trimmed, ":")
            tokens, ok := tokenize(head)
            if !ok {
                fmt.printf("Fix\n  Could not parse header on line %d\n", i+1)
                return entries, false
            }
            current = tokens
            continue
        }

        if len(current) == 0 {
            fmt.printf("Fix\n  Entry before any section on line %d\n", i+1)
            return entries, false
        }

        tokens, ok := tokenize(trimmed)
        if !ok {
            fmt.printf("Fix\n  Could not parse entry on line %d\n", i+1)
            return entries, false
        }
        append(&entries, Entry{header = current, tokens = tokens, line = i+1})
    }

    return entries, true
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
            if len(e.tokens) >= 2 do append(&cfg.tools, Tool{name = e.tokens[0], version = e.tokens[1]})
        case "services":
            if len(e.tokens) >= 2 && e.tokens[0] == "compose" do append(&cfg.compose_files, e.tokens[1])
        case "env":
            if len(e.tokens) >= 2 {
                if e.tokens[0] == "example" do append(&cfg.env_examples, e.tokens[1])
                if e.tokens[0] == "file" do append(&cfg.env_files, e.tokens[1])
            }
        case "scripts":
            if len(e.header) >= 2 do cfg.script_runner = e.header[1]
            if len(e.tokens) >= 1 do append(&cfg.scripts, e.tokens[0])
        }
    }

    return cfg
}
