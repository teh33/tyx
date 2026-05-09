package main

import "core:fmt"
import "core:strings"

SECTION_PROJECT :: "project"
SECTION_TOOLS :: "tools"
SECTION_SERVICES :: "services"
SECTION_ENV :: "env"
SECTION_SCRIPTS :: "scripts"

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
