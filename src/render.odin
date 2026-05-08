package main

import "core:fmt"
import "core:strings"

render_project :: proc(info: Repo_Info) -> string {
    b := strings.builder_make()
    strings.write_string(&b, "project:\n\n")

    strings.write_string(&b, "tools:\n")
    strings.write_string(&b, fmt.tprintf("node %s\n", info.node))
    strings.write_string(&b, fmt.tprintf("%s %s\n", info.package_manager, info.package_manager_version))

    if len(info.compose_files) > 0 {
        strings.write_string(&b, "\nservices:\n")
        for f in info.compose_files do strings.write_string(&b, fmt.tprintf("compose %s\n", f))
    }

    if info.has_env_example {
        strings.write_string(&b, "\nenv:\n")
        strings.write_string(&b, "example .env.example\n")
    }

    if len(info.scripts) > 0 {
        strings.write_string(&b, fmt.tprintf("\nscripts %s:\n", info.package_manager))
        for s in info.scripts do strings.write_string(&b, fmt.tprintf("%s\n", quote_if_needed(s)))
    }

    return strings.to_string(b)
}
