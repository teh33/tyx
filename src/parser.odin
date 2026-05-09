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

