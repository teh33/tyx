package main

import json "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

scan_repo :: proc(path: string) -> (Repo_Info, bool) {
    info: Repo_Info
    pkg_path := join2(path, "package.json")

    if !os.is_file(pkg_path) {
        fmt.println("Unsupported")
        fmt.println("  No package.json found")
        fmt.println("")
        fmt.println("Fix")
        fmt.println("  The Odin spike only supports Node/TypeScript fixture repos.")
        return info, false
    }

    bytes, err := os.read_entire_file(pkg_path, context.allocator)
    if err != nil {
        fmt.printf("Fix\n  Could not read %s: %v\n", pkg_path, err)
        return info, false
    }

    root, json_err := json.parse(bytes, .JSON, false, context.allocator)
    if json_err != nil {
        fmt.printf("Fix\n  Could not parse %s: %v\n", pkg_path, json_err)
        return info, false
    }

    root_obj: json.Object
    #partial switch v in root {
    case json.Object:
        root_obj = v
    case:
        fmt.printf("Fix\n  %s must contain a JSON object\n", pkg_path)
        return info, false
    }

    scan_package_manager(root_obj, &info)
    scan_node_version(path, root_obj, &info)
    scan_scripts(root_obj, &info)
    scan_compose_files(path, &info)
    info.has_env_example = os.is_file(join2(path, ".env.example"))

    if info.package_manager == "" do infer_package_manager_from_lockfiles(path, &info)
    return info, true
}

scan_package_manager :: proc(root: json.Object, info: ^Repo_Info) {
    if pmv, ok := root["packageManager"]; ok {
        #partial switch pm in pmv {
        case json.String:
            parse_package_manager(pm, info)
        }
    }
}

scan_node_version :: proc(path: string, root: json.Object, info: ^Repo_Info) {
    if engines, ok := root["engines"]; ok {
        #partial switch eng in engines {
        case json.Object:
            if nv, ok2 := eng["node"]; ok2 {
                #partial switch node_s in nv {
                case json.String:
                    info.node = choose_node_major(node_s)
                }
            }
        }
    }

    nvm_path := join2(path, ".nvmrc")
    if os.is_file(nvm_path) {
        nb, _ := os.read_entire_file(nvm_path, context.allocator)
        n := choose_node_major(strings.trim_space(string(nb)))
        if n != "" do info.node = n
    }

    if info.node == "" do info.node = "22"
}

scan_scripts :: proc(root: json.Object, info: ^Repo_Info) {
    scripts_v, ok := root["scripts"]
    if !ok do return

    #partial switch scripts in scripts_v {
    case json.Object:
        preferred := [?]string{"dev", "test", "lint", "build"}
        added := make(map[string]bool)

        for s in preferred {
            if _, exists := scripts[s]; exists {
                append(&info.scripts, s)
                added[s] = true
            }
        }

        rest: [dynamic]string
        for name, _ in scripts {
            if !added[name] do append(&rest, name)
        }
        slice.sort(rest[:])
        for name in rest do append(&info.scripts, name)
    }
}

scan_compose_files :: proc(path: string, info: ^Repo_Info) {
    compose_candidates := [?]string{
        "compose.yaml",
        "compose.yml",
        "docker-compose.yaml",
        "docker-compose.yml",
        "compose.override.yaml",
        "compose.override.yml",
        "docker-compose.override.yaml",
        "docker-compose.override.yml",
    }

    for c in compose_candidates {
        if os.is_file(join2(path, c)) do append(&info.compose_files, c)
    }
}

infer_package_manager_from_lockfiles :: proc(path: string, info: ^Repo_Info) {
    if os.is_file(join2(path, "pnpm-lock.yaml")) {
        info.package_manager = "pnpm"
        info.package_manager_version = "latest"
    } else if os.is_file(join2(path, "yarn.lock")) {
        info.package_manager = "yarn"
        info.package_manager_version = "latest"
    } else if os.is_file(join2(path, "bun.lock")) || os.is_file(join2(path, "bun.lockb")) {
        info.package_manager = "bun"
        info.package_manager_version = "latest"
    } else {
        info.package_manager = "npm"
        info.package_manager_version = "latest"
    }
}

parse_package_manager :: proc(pm: string, info: ^Repo_Info) {
    parts := strings.split(pm, "@")
    if len(parts) >= 2 {
        info.package_manager = parts[0]
        info.package_manager_version = parts[1]
    } else {
        info.package_manager = pm
        info.package_manager_version = "latest"
    }
}

choose_node_major :: proc(expr: string) -> string {
    // Spike policy: choose the newest active LTS major satisfying common >= ranges.
    if strings.contains(expr, "22") do return "22"
    if strings.contains(expr, ">=20") do return "22"
    if strings.contains(expr, "20") do return "20"
    if strings.contains(expr, "18") do return "18"
    if n, ok := strconv.parse_int(expr, 10); ok do return fmt.tprintf("%d", n)
    return "22"
}
