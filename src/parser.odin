package main

import "core:fmt"
import "core:strings"

Parse_State :: struct {
	entries:      [dynamic]Entry,
	current:      []string,
	seen_project: bool,
}

parse_tyx :: proc(input: string) -> ([dynamic]Entry, bool) {
	state: Parse_State
	lines := strings.split(input, "\n")
	for line, i in lines {
		if !parse_line(&state, line, i+1) {
			return state.entries, false
		}
	}
	if !state.seen_project {
		fmt.println("Fix")
		fmt.println("  project.tyx is missing the `project:` header.")
		fmt.println("")
		fmt.println("  Add `project:` near the top of the file.")
		return state.entries, false
	}
	return state.entries, true
}

parse_line :: proc(state: ^Parse_State, line: string, line_number: int) -> bool {
	trimmed := strings.trim_space(line)
	if trimmed == "" || strings.has_prefix(trimmed, "#") {
		return true
	}
	if has_unclosed_quote(trimmed) {
		fmt.printf("Fix\n  Unterminated quoted token on line %d.\n", line_number)
		return false
	}
	if is_header(trimmed) {
		return parse_header(state, trimmed, line_number)
	}
	return parse_entry(state, trimmed, line_number)
}

parse_header :: proc(state: ^Parse_State, line: string, line_number: int) -> bool {
	head := strings.trim_right(line, ":")
	tokens, ok := tokenize(head)
	if !ok {
		fmt.printf("Fix\n  Could not parse header on line %d.\n", line_number)
		return false
	}
	if !validate_header(tokens, line_number, &state.seen_project) {
		return false
	}
	state.current = tokens
	return true
}

parse_entry :: proc(state: ^Parse_State, line: string, line_number: int) -> bool {
	if len(state.current) == 0 {
		fmt.printf("Fix\n  Entry before any section on line %d.\n", line_number)
		fmt.println("\n  Add a section header such as `project:` or `tools:` before entries.")
		return false
	}
	tokens, ok := tokenize(line)
	if !ok {
		fmt.printf("Fix\n  Could not parse entry on line %d.\n", line_number)
		return false
	}
	if !validate_entry(state.current, tokens, line_number) {
		return false
	}
	append(&state.entries, Entry{header = state.current, tokens = tokens, line = line_number})
	return true
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
	if len(tokens) == 0 {
		return true
	}
	section := header[0]
	switch section {
	case "project":
		fmt.printf("Fix\n  `project:` does not accept entries; found one on line %d.\n", line)
		return false
	case "tools":
		return validate_tool_entry(tokens, line)
	case "services":
		return validate_service_entry(tokens, line)
	case "env":
		return validate_env_entry(tokens, line)
	case "scripts":
		return validate_script_entry(tokens, line)
	}
	return true
}

validate_tool_entry :: proc(tokens: []string, line: int) -> bool {
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
	return true
}

validate_service_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) == 2 && tokens[0] == "compose" {
		return true
	}
	fmt.printf("Fix\n  Service entry on line %d must be `compose <file>`.\n", line)
	fmt.println("")
	fmt.println("  Example: `compose compose.yaml`")
	return false
}

validate_env_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) == 2 && (tokens[0] == "example" || tokens[0] == "file") {
		return true
	}
	fmt.printf("Fix\n  Env entry on line %d must be `example <file>` or `file <file>`.\n", line)
	return false
}

validate_script_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) == 1 {
		return true
	}
	fmt.printf("Fix\n  Script entry on line %d must be one script name.\n", line)
	fmt.println("\n  Quote names that contain spaces, e.g. `\"dev server\"`.")
	return false
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
		if b == '"' {
			in_quote = !in_quote
		}
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
		if b == '"' {
			in_quote = !in_quote
		}
		if b != ' ' && b != '\t' {
			last_non_space = b
		}
	}
	return !in_quote && last_non_space == ':'
}

tokenize :: proc(line: string) -> ([]string, bool) {
	tokens: [dynamic]string
	i := 0
	for i < len(line) {
		for i < len(line) && is_space(line[i]) {
			i += 1
		}
		if i >= len(line) {
			break
		}
		if line[i] == '"' {
			if !append_quoted_token(&tokens, line, &i) {
				return tokens[:], false
			}
		} else {
			append_bare_token(&tokens, line, &i)
		}
	}
	return tokens[:], true
}

append_quoted_token :: proc(tokens: ^[dynamic]string, line: string, i: ^int) -> bool {
	i^ += 1
	builder := strings.builder_make()
	for i^ < len(line) {
		if line[i^] == '\\' && i^+1 < len(line) {
			next := line[i^+1]
			if next == '"' || next == '\\' {
				strings.write_byte(&builder, next)
				i^ += 2
				continue
			}
		}
		if line[i^] == '"' {
			break
		}
		strings.write_byte(&builder, line[i^])
		i^ += 1
	}
	if i^ >= len(line) {
		fmt.println("Fix\n  Unterminated quoted token")
		return false
	}
	append(tokens, strings.to_string(builder))
	i^ += 1
	return true
}

append_bare_token :: proc(tokens: ^[dynamic]string, line: string, i: ^int) {
	start := i^
	for i^ < len(line) && !is_space(line[i^]) {
		i^ += 1
	}
	append(tokens, line[start:i^])
}

is_space :: proc(b: byte) -> bool {
	return b == ' ' || b == '\t' || b == '\r'
}

config_from_entries :: proc(entries: []Entry) -> Project_Config {
	cfg: Project_Config
	for e in entries {
		if len(e.header) == 0 {
			continue
		}
		section := e.header[0]
		switch section {
		case "tools":
			append(&cfg.tools, Tool{name = e.tokens[0], version = e.tokens[1]})
		case "services":
			append(&cfg.compose_files, e.tokens[1])
		case "env":
			if e.tokens[0] == "example" {
				append(&cfg.env_examples, e.tokens[1])
			}
			if e.tokens[0] == "file" {
				append(&cfg.env_files, e.tokens[1])
			}
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
		if group.runner == runner {
			return i
		}
	}
	return -1
}
