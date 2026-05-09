package main

import "core:os"

FILE_STATUS_PRESENT :: "present"
FILE_STATUS_MISSING :: "missing"

File_Check :: struct {
	kind:   string,
	path:   string,
	status: string,
}

check_env_files :: proc(root: string, cfg: Project_Config) -> [dynamic]File_Check {
	checks: [dynamic]File_Check
	append_file_checks(&checks, root, "example", cfg.env_examples[:])
	append_file_checks(&checks, root, "file", cfg.env_files[:])
	return checks
}

check_compose_files :: proc(root: string, cfg: Project_Config) -> [dynamic]File_Check {
	checks: [dynamic]File_Check
	append_file_checks(&checks, root, "compose", cfg.compose_files[:])
	return checks
}

append_file_checks :: proc(checks: ^[dynamic]File_Check, root, kind: string, paths: []string) {
	for path in paths {
		append(checks, File_Check{kind = kind, path = path, status = file_status(root, path)})
	}
}

file_status :: proc(root, path: string) -> string {
	if os.is_file(join2(root, path)) {
		return FILE_STATUS_PRESENT
	}
	return FILE_STATUS_MISSING
}

check_dependencies :: proc(root: string, cfg: Project_Config) -> [dynamic]Dependency_Check {
	checks: [dynamic]Dependency_Check
	for group in cfg.script_groups {
		if !is_node_runner(group.runner) {
			continue
		}
		append(&checks, node_dependency_check(root, group.runner))
	}
	return checks
}

node_dependency_check :: proc(root, runner: string) -> Dependency_Check {
	manifest := "package.json"
	dependency_path := "node_modules"
	status := FILE_STATUS_MISSING
	if os.is_file(join2(root, manifest)) && os.is_dir(join2(root, dependency_path)) {
		status = FILE_STATUS_PRESENT
	}
	return Dependency_Check{runner = runner, manifest = manifest, path = dependency_path, status = status}
}

is_node_runner :: proc(runner: string) -> bool {
	switch runner {
	case "npm", "pnpm", "yarn", "bun":
		return true
	}
	return false
}
