package main

import "core:fmt"
import fp "core:path/filepath"
import "core:strings"

join2 :: proc(a, b: string) -> string {
	joined, _ := fp.join([]string{a, b})
	return joined
}

needs_quote :: proc(s: string) -> bool {
	for c in s {
		if c == ' ' || c == '\t' {
			return true
		}
	}
	return false
}

quote_if_needed :: proc(s: string) -> string {
	if needs_quote(s) {
		return fmt.tprintf("\"%s\"", s)
	}
	return s
}

join_display :: proc(items: []string) -> string {
	b := strings.builder_make()
	write_display_items(&b, items)
	return strings.to_string(b)
}

write_display_items :: proc(b: ^strings.Builder, items: []string) {
	for item, i in items {
		if i > 0 {
			strings.write_string(b, ", ")
		}
		strings.write_string(b, quote_if_needed(item))
	}
}

first_script :: proc(cfg: Project_Config) -> (string, bool) {
	for group in cfg.script_groups {
		if len(group.scripts) > 0 {
			return group.scripts[0], true
		}
	}
	return "", false
}

resolve_script :: proc(cfg: Project_Config, name: string) -> ([]string, bool) {
	for group in cfg.script_groups {
		for script in group.scripts {
			if script == name {
				return script_command(group.runner, name), true
			}
		}
	}
	return nil, false
}

script_command :: proc(runner, name: string) -> []string {
	command := make([]string, 2)
	command[0] = runner
	command[1] = name
	return command
}
