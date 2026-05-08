package main

import "core:os"

File_Check :: struct {
    kind:   string,
    path:   string,
    status: string,
}

check_env_files :: proc(root: string, cfg: Project_Config) -> [dynamic]File_Check {
    checks: [dynamic]File_Check
    for f in cfg.env_examples {
        status := "missing"
        if os.is_file(join2(root, f)) do status = "present"
        append(&checks, File_Check{kind = "example", path = f, status = status})
    }
    for f in cfg.env_files {
        status := "missing"
        if os.is_file(join2(root, f)) do status = "present"
        append(&checks, File_Check{kind = "file", path = f, status = status})
    }
    return checks
}

check_compose_files :: proc(root: string, cfg: Project_Config) -> [dynamic]File_Check {
    checks: [dynamic]File_Check
    for f in cfg.compose_files {
        status := "missing"
        if os.is_file(join2(root, f)) do status = "present"
        append(&checks, File_Check{kind = "compose", path = f, status = status})
    }
    return checks
}
