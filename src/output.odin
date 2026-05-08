package main

import "core:fmt"

print_usage :: proc() {
    fmt.println("Tyx spike")
    fmt.println("")
    fmt.println("Usage")
    fmt.println("  tyx init [path]")
    fmt.println("  tyx up [path]")
    fmt.println("  tyx parse [project.tyx]")
    fmt.println("  tyx run [--path <path>] <script|command> [args...]")
}

print_init_success :: proc(info: Repo_Info) {
    fmt.println("Tyx initialized this repo")
    fmt.println("")
    fmt.println("Wrote")
    fmt.println("  ✓ project.tyx")
    fmt.println("")
    fmt.println("Detected")
    if info.node != "" do fmt.printf("  ✓ node %-15s package.json#engines.node/.nvmrc\n", info.node)
    if info.package_manager != "" do fmt.printf("  ✓ %-4s %-15s package.json#packageManager\n", info.package_manager, info.package_manager_version)
    for f in info.compose_files do fmt.printf("  ✓ compose             %s\n", f)
    if info.has_env_example do fmt.println("  ✓ env example         .env.example")
    if info.has_env_file do fmt.println("  ✓ env file            .env")
    if len(info.scripts) > 0 do fmt.printf("  ✓ scripts             %s\n", join_display(info.scripts[:]))
    fmt.println("")
    fmt.println("Next")
    fmt.println("  tyx up")
    if len(info.scripts) > 0 do fmt.printf("  tyx run %s\n", quote_if_needed(info.scripts[0]))
}

print_parsed_config :: proc(cfg: Project_Config) {
    fmt.println("Parsed project.tyx")
    fmt.println("")
    fmt.println("Tools")
    for t in cfg.tools do fmt.printf("  ✓ %s %s\n", t.name, t.version)

    if len(cfg.compose_files) > 0 {
        fmt.println("")
        fmt.println("Services")
        for f in cfg.compose_files do fmt.printf("  ✓ compose %s\n", f)
    }

    if len(cfg.env_examples) > 0 || len(cfg.env_files) > 0 {
        fmt.println("")
        fmt.println("Env")
        for f in cfg.env_examples do fmt.printf("  ✓ example %s\n", f)
        for f in cfg.env_files do fmt.printf("  ✓ file %s\n", f)
    }

    print_script_groups(cfg)
}

print_up_success :: proc(cfg: Project_Config, resolved_tools: []Resolved_Tool) {
    fmt.println("Tyx prepared this repo")
    fmt.println("")
    fmt.println("Wrote")
    fmt.println("  ✓ tyx.lock")

    if len(resolved_tools) > 0 {
        fmt.println("")
        fmt.println("Tools")
        for t in resolved_tools {
            if t.status == "present" {
                fmt.printf("  ✓ %s %s present", t.name, t.requested)
                if t.version != "" do fmt.printf(" (%s)", t.version)
                fmt.println("")
            } else if t.status == "missing" {
                fmt.printf("  ! %s %s missing\n", t.name, t.requested)
            } else {
                fmt.printf("  ! %s %s unsupported\n", t.name, t.requested)
            }
        }
    }

    if len(cfg.compose_files) > 0 {
        fmt.println("")
        fmt.println("Services")
        for f in cfg.compose_files do fmt.printf("  ✓ compose %s\n", f)
    }

    if len(cfg.env_examples) > 0 || len(cfg.env_files) > 0 {
        fmt.println("")
        fmt.println("Env")
        for f in cfg.env_examples do fmt.printf("  ✓ example %s\n", f)
        for f in cfg.env_files do fmt.printf("  ✓ file %s\n", f)
    }

    print_script_groups(cfg)
    print_tool_fixes(resolved_tools)

    fmt.println("")
    fmt.println("Ready")
    script, ok := first_script(cfg)
    if ok {
        fmt.printf("  tyx run %s\n", quote_if_needed(script))
    } else {
        fmt.println("  project.tyx parsed successfully")
    }
}

print_script_groups :: proc(cfg: Project_Config) {
    for group in cfg.script_groups {
        if len(group.scripts) == 0 do continue
        fmt.println("")
        fmt.printf("Scripts %s\n", group.runner)
        for s in group.scripts do fmt.printf("  ✓ %s\n", s)
    }
}

print_tool_fixes :: proc(resolved_tools: []Resolved_Tool) {
    printed := false
    for t in resolved_tools {
        if t.status == "present" do continue
        if !printed {
            fmt.println("")
            fmt.println("Fix")
            printed = true
        }
        if t.status == "missing" {
            fmt.printf("  Install %s %s or make it available on PATH.\n", t.name, t.requested)
        } else {
            fmt.printf("  Tool %s is not supported by Tyx tool detection yet.\n", t.name)
        }
    }
}
