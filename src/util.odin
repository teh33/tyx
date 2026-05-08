package main

import fp "core:path/filepath"
import "core:fmt"
import "core:strings"

join2 :: proc(a, b: string) -> string {
    joined, _ := fp.join([]string{a, b})
    return joined
}

needs_quote :: proc(s: string) -> bool {
    for c in s {
        if c == ' ' || c == '\t' do return true
    }
    return false
}

quote_if_needed :: proc(s: string) -> string {
    if needs_quote(s) do return fmt.tprintf("\"%s\"", s)
    return s
}

join_display :: proc(items: []string) -> string {
    b := strings.builder_make()
    for item, i in items {
        if i > 0 do strings.write_string(&b, ", ")
        strings.write_string(&b, quote_if_needed(item))
    }
    return strings.to_string(b)
}

first_script :: proc(cfg: Project_Config) -> (string, bool) {
    for group in cfg.script_groups {
        if len(group.scripts) > 0 do return group.scripts[0], true
    }
    return "", false
}

resolve_script :: proc(cfg: Project_Config, name: string) -> ([]string, bool) {
    for group in cfg.script_groups {
        for script in group.scripts {
            if script == name {
                command := make([]string, 2)
                command[0] = group.runner
                command[1] = name
                return command, true
            }
        }
    }
    return nil, false
}
