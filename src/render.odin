package main

import "core:fmt"
import "core:strings"

render_project :: proc(info: Repo_Info) -> string {
	b := strings.builder_make()
	strings.write_string(&b, "project:\n\n")
	render_project_tools(&b, info)
	render_project_services(&b, info.compose_files[:])
	render_project_env(&b, info)
	render_project_scripts(&b, info)
	return strings.to_string(b)
}

render_project_tools :: proc(b: ^strings.Builder, info: Repo_Info) {
	strings.write_string(b, "tools:\n")
	strings.write_string(b, fmt.tprintf("node %s\n", info.node))
	strings.write_string(b, fmt.tprintf("%s %s\n", info.package_manager, info.package_manager_version))
}

render_project_services :: proc(b: ^strings.Builder, compose_files: []string) {
	if len(compose_files) == 0 {
		return
	}
	strings.write_string(b, "\nservices:\n")
	for f in compose_files {
		strings.write_string(b, fmt.tprintf("compose %s\n", f))
	}
}

render_project_env :: proc(b: ^strings.Builder, info: Repo_Info) {
	if !info.has_env_example && !info.has_env_file {
		return
	}
	strings.write_string(b, "\nenv:\n")
	if info.has_env_example {
		strings.write_string(b, "example .env.example\n")
	}
	if info.has_env_file {
		strings.write_string(b, "file .env\n")
	}
}

render_project_scripts :: proc(b: ^strings.Builder, info: Repo_Info) {
	if len(info.scripts) == 0 {
		return
	}
	strings.write_string(b, fmt.tprintf("\nscripts %s:\n", info.package_manager))
	for s in info.scripts {
		strings.write_string(b, fmt.tprintf("%s\n", quote_if_needed(s)))
	}
}
