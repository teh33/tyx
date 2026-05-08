package main

import "core:fmt"
import "core:os"

cmd_init :: proc(path: string) -> bool {
    out_path := join2(path, "project.tyx")
    if os.is_file(out_path) {
        fmt.println("Fix")
        fmt.println("  project.tyx already exists")
        fmt.println("")
        fmt.println("  Remove it before running tyx init again.")
        return false
    }

    info, ok := scan_repo(path)
    if !ok do return false

    config := render_project(info)
    if err := os.write_entire_file(out_path, config); err != nil {
        fmt.printf("Fix\n  Could not write %s: %v\n", out_path, err)
        return false
    }

    print_init_success(info)
    return true
}

cmd_parse :: proc(path: string) -> bool {
    cfg, ok := load_project_config(path)
    if !ok do return false
    print_parsed_config(cfg)
    return true
}

cmd_up :: proc(path: string) -> bool {
    project_path := join2(path, "project.tyx")
    cfg, ok := load_project_config(project_path)
    if !ok do return false

    resolved_tools := resolve_tools(cfg)
    compose_checks := check_compose_files(path, cfg)
    env_checks := check_env_files(path, cfg)
    dependency_checks := check_dependencies(path, cfg)
    lock_path := join2(path, "tyx.lock")
    lock := render_lock(cfg, resolved_tools[:], compose_checks[:], env_checks[:], dependency_checks[:])
    if err := os.write_entire_file(lock_path, lock); err != nil {
        fmt.printf("Fix\n  Could not write %s: %v\n", lock_path, err)
        return false
    }

    print_up_success(cfg, resolved_tools[:], compose_checks[:], env_checks[:], dependency_checks[:])
    return true
}

load_project_config :: proc(path: string) -> (Project_Config, bool) {
    cfg: Project_Config
    bytes, err := os.read_entire_file(path, context.allocator)
    if err != nil {
        fmt.printf("Fix\n  Could not read %s: %v\n", path, err)
        return cfg, false
    }

    entries, ok := parse_tyx(string(bytes))
    if !ok do return cfg, false

    cfg = config_from_entries(entries[:])
    return cfg, true
}

cmd_run :: proc(path: string, args: []string) -> bool {
    command := args
    project_path := join2(path, "project.tyx")
    if os.is_file(project_path) {
        cfg, ok := load_project_config(project_path)
        if ok {
            if resolved, found := resolve_script(cfg, args[0]); found do command = resolved
        }
    }

    desc := os.Process_Desc{command = command, working_dir = path}
    state, stdout, stderr, err := os.process_exec(desc, context.allocator)
    if err != nil {
        fmt.printf("Fix\n  Could not run command: %v\n", err)
        return false
    }

    if len(stdout) > 0 do fmt.print(string(stdout))
    if len(stderr) > 0 do fmt.eprint(string(stderr))
    return state.exited && state.exit_code == 0
}
