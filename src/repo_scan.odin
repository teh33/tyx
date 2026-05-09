package main

import json "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

NODE_VERSION_FILES :: [?]string{".nvmrc", ".node-version"}
COMPOSE_CANDIDATES :: [?]string{
	"compose.yaml",
	"compose.yml",
	"docker-compose.yaml",
	"docker-compose.yml",
	"compose.override.yaml",
	"compose.override.yml",
	"docker-compose.override.yaml",
	"docker-compose.override.yml",
}
SCRIPT_ORDER :: [?]string{"dev", "test", "lint", "build"}

scan_repo :: proc(path: string) -> (Repo_Info, bool) {
	info: Repo_Info
	root, ok := read_package_json(path)
	if !ok {
		return info, false
	}
	scan_package_manager(root, &info)
	scan_node_version(path, root, &info)
	scan_scripts(root, &info)
	scan_compose_files(path, &info)
	scan_env_files(path, &info)
	if info.package_manager == "" {
		if !infer_package_manager_from_lockfiles(path, &info) {
			return info, false
		}
	}
	return info, true
}

read_package_json :: proc(path: string) -> (json.Object, bool) {
	pkg_path := join2(path, "package.json")
	root_obj: json.Object
	if !os.is_file(pkg_path) {
		fmt.println("Unsupported")
		fmt.println("  No package.json found")
		fmt.println("")
		fmt.println("Fix")
		fmt.println("  The Odin spike only supports Node/TypeScript fixture repos.")
		return root_obj, false
	}
	bytes, err := os.read_entire_file(pkg_path, context.allocator)
	if err != nil {
		fmt.printf("Fix\n  Could not read %s: %v\n", pkg_path, err)
		return root_obj, false
	}
	root, json_err := json.parse(bytes, .JSON, false, context.allocator)
	if json_err != nil {
		fmt.printf("Fix\n  Could not parse %s: %v\n", pkg_path, json_err)
		return root_obj, false
	}
	#partial switch v in root {
	case json.Object:
		return v, true
	case:
		fmt.printf("Fix\n  %s must contain a JSON object\n", pkg_path)
		return root_obj, false
	}
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
	if engines_node, ok := json_object_string(root, "engines", "node"); ok {
		info.node = choose_node_major(engines_node)
	}
	for file in NODE_VERSION_FILES {
		if version, ok := read_trimmed_file(join2(path, file)); ok {
			if major := choose_node_major(version); major != "" {
				info.node = major
			}
		}
	}
	if info.node == "" {
		info.node = "22"
	}
}

scan_scripts :: proc(root: json.Object, info: ^Repo_Info) {
	scripts_v, ok := root["scripts"]
	if !ok {
		return
	}
	#partial switch scripts in scripts_v {
	case json.Object:
		append_ordered_scripts(&info.scripts, scripts)
	}
}

append_ordered_scripts :: proc(out: ^[dynamic]string, scripts: json.Object) {
	added := make(map[string]bool)
	for name in SCRIPT_ORDER {
		if _, exists := scripts[name]; exists {
			append(out, name)
			added[name] = true
		}
	}
	rest: [dynamic]string
	for name, _ in scripts {
		if !added[name] {
			append(&rest, name)
		}
	}
	slice.sort(rest[:])
	for name in rest {
		append(out, name)
	}
}

scan_compose_files :: proc(path: string, info: ^Repo_Info) {
	for file in COMPOSE_CANDIDATES {
		if os.is_file(join2(path, file)) {
			append(&info.compose_files, file)
		}
	}
}

scan_env_files :: proc(path: string, info: ^Repo_Info) {
	info.has_env_example = os.is_file(join2(path, ".env.example"))
	info.has_env_file = os.is_file(join2(path, ".env"))
}

infer_package_manager_from_lockfiles :: proc(path: string, info: ^Repo_Info) -> bool {
	detected: [dynamic]string
	append_lockfile_match(&detected, path, "pnpm", "pnpm-lock.yaml")
	append_lockfile_match(&detected, path, "yarn", "yarn.lock")
	append_lockfile_match(&detected, path, "bun", "bun.lock")
	append_lockfile_match(&detected, path, "bun", "bun.lockb")
	append_lockfile_match(&detected, path, "npm", "package-lock.json")
	if len(detected) > 1 {
		print_multiple_lockfiles(detected[:])
		return false
	}
	if len(detected) == 1 {
		info.package_manager = detected[0]
		info.package_manager_version = "latest"
	} else {
		info.package_manager = "npm"
		info.package_manager_version = "latest"
	}
	return true
}

append_lockfile_match :: proc(detected: ^[dynamic]string, path, name, file: string) {
	if os.is_file(join2(path, file)) {
		append(detected, name)
	}
}

print_multiple_lockfiles :: proc(detected: []string) {
	fmt.println("Fix")
	fmt.println("  Multiple package manager lockfiles detected:")
	for name in detected {
		fmt.printf("    %s\n", name)
	}
	fmt.println("")
	fmt.println("  Remove stale lockfiles or add packageManager to package.json.")
}

parse_package_manager :: proc(pm: string, info: ^Repo_Info) {
	parts := strings.split(pm, "@")
	if len(parts) >= 2 {
		info.package_manager = parts[0]
		info.package_manager_version = parts[1]
		return
	}
	info.package_manager = pm
	info.package_manager_version = "latest"
}

choose_node_major :: proc(expr: string) -> string {
	// Spike policy: choose the newest active LTS major satisfying common >= ranges.
	if strings.contains(expr, "22") || strings.contains(expr, ">=20") {
		return "22"
	}
	if strings.contains(expr, "20") {
		return "20"
	}
	if strings.contains(expr, "18") {
		return "18"
	}
	if n, ok := strconv.parse_int(expr, 10); ok {
		return fmt.tprintf("%d", n)
	}
	return "22"
}

json_object_string :: proc(root: json.Object, object_key, string_key: string) -> (string, bool) {
	if object_v, ok := root[object_key]; ok {
		#partial switch object in object_v {
		case json.Object:
			if string_v, string_ok := object[string_key]; string_ok {
				#partial switch value in string_v {
				case json.String:
					return value, true
				}
			}
		}
	}
	return "", false
}

read_trimmed_file :: proc(path: string) -> (string, bool) {
	if !os.is_file(path) {
		return "", false
	}
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return "", false
	}
	return strings.trim_space(string(bytes)), true
}
