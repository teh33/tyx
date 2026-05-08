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
