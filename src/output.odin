package main

import "core:fmt"

print_usage :: proc() {
    fmt.println("Tyx spike")
    fmt.println("")
    fmt.println("Usage")
    fmt.println("  tyx init [path]")
    fmt.println("  tyx parse [project.tyx]")
    fmt.println("  tyx run <command> [args...]")
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

    if len(cfg.scripts) > 0 {
        fmt.println("")
        fmt.printf("Scripts %s\n", cfg.script_runner)
        for s in cfg.scripts do fmt.printf("  ✓ %s\n", s)
    }
}

print_up_success :: proc(cfg: Project_Config) {
    fmt.println("Tyx prepared this repo")
    fmt.println("")
    fmt.println("Wrote")
    fmt.println("  ✓ tyx.lock")

    if len(cfg.tools) > 0 {
        fmt.println("")
        fmt.println("Tools")
        for t in cfg.tools do fmt.printf("  ✓ %s %s requested\n", t.name, t.version)
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

    if len(cfg.scripts) > 0 {
        fmt.println("")
        fmt.printf("Scripts %s\n", cfg.script_runner)
        for s in cfg.scripts do fmt.printf("  ✓ %s\n", s)
    }

    fmt.println("")
    fmt.println("Ready")
    if len(cfg.scripts) > 0 {
        fmt.printf("  tyx run %s\n", quote_if_needed(cfg.scripts[0]))
    } else {
        fmt.println("  project.tyx parsed successfully")
    }
}
