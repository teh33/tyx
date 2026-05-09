package main

import "core:fmt"

print_usage :: proc() {
	fmt.println("Tyx spike")
	fmt.println("")
	fmt.println("Usage")
	fmt.println("  tyx init [path]")
	fmt.println("  tyx up [path]")
	fmt.println("  tyx down [path]")
	fmt.println("  tyx parse [project.tyx]")
	fmt.println("  tyx run [--path <path>] <script|command> [args...]")
}

print_init_success :: proc(info: Repo_Info) {
	fmt.println("Tyx initialized this repo")
	print_wrote_project()
	print_detected_repo(info)
	fmt.println("")
	fmt.println("Next")
	fmt.println("  tyx up")
	if len(info.scripts) > 0 {
		fmt.printf("  tyx run %s\n", quote_if_needed(info.scripts[0]))
	}
}

print_wrote_project :: proc() {
	fmt.println("")
	fmt.println("Wrote")
	fmt.println("  ✓ project.tyx")
}

print_detected_repo :: proc(info: Repo_Info) {
	fmt.println("")
	fmt.println("Detected")
	if info.node != "" {
		fmt.printf("  ✓ node %-15s package.json#engines.node/.nvmrc\n", info.node)
	}
	if info.package_manager != "" {
		fmt.printf("  ✓ %-4s %-15s package.json#packageManager\n", info.package_manager, info.package_manager_version)
	}
	for f in info.compose_files {
		fmt.printf("  ✓ compose             %s\n", f)
	}
	if info.has_env_example {
		fmt.println("  ✓ env example         .env.example")
	}
	if info.has_env_file {
		fmt.println("  ✓ env file            .env")
	}
	if len(info.scripts) > 0 {
		fmt.printf("  ✓ scripts             %s\n", join_display(info.scripts[:]))
	}
}

print_parsed_config :: proc(cfg: Project_Config) {
	fmt.println("Parsed project.tyx")
	print_config_tools(cfg.tools[:])
	print_config_services(cfg.compose_files[:])
	print_config_env(cfg.env_examples[:], cfg.env_files[:])
	print_script_groups(cfg)
}

print_up_success :: proc(cfg: Project_Config, resolved_tools: []Resolved_Tool, compose_checks: []File_Check, env_checks: []File_Check, dependency_checks: []Dependency_Check) {
	fmt.println("Tyx prepared this repo")
	fmt.println("")
	fmt.println("Wrote")
	fmt.println("  ✓ tyx.lock")
	print_resolved_tools(resolved_tools)
	print_file_checks("Services", compose_checks)
	print_file_checks("Env", env_checks)
	print_dependency_checks(dependency_checks)
	print_script_groups(cfg)
	print_fixes(resolved_tools, compose_checks, env_checks, dependency_checks)
	print_ready(cfg)
}

print_down_start :: proc(compose_checks: []File_Check) {
	fmt.println("Tyx tearing down this repo")
	if len(compose_checks) == 0 {
		fmt.println("")
		fmt.println("Ready")
		fmt.println("  no runtime services declared")
		return
	}
	print_file_checks("Services", compose_checks)
}

print_config_tools :: proc(tools: []Tool) {
	if len(tools) == 0 {
		return
	}
	fmt.println("")
	fmt.println("Tools")
	for t in tools {
		fmt.printf("  ✓ %s %s\n", t.name, t.version)
	}
}

print_config_services :: proc(compose_files: []string) {
	if len(compose_files) == 0 {
		return
	}
	fmt.println("")
	fmt.println("Services")
	for f in compose_files {
		fmt.printf("  ✓ compose %s\n", f)
	}
}

print_config_env :: proc(examples, files: []string) {
	if len(examples) == 0 && len(files) == 0 {
		return
	}
	fmt.println("")
	fmt.println("Env")
	for f in examples {
		fmt.printf("  ✓ example %s\n", f)
	}
	for f in files {
		fmt.printf("  ✓ file %s\n", f)
	}
}

print_resolved_tools :: proc(resolved_tools: []Resolved_Tool) {
	if len(resolved_tools) == 0 {
		return
	}
	fmt.println("")
	fmt.println("Tools")
	for t in resolved_tools {
		print_resolved_tool(t)
	}
}

print_resolved_tool :: proc(t: Resolved_Tool) {
	if t.status == "present" && t.matches {
		fmt.printf("  ✓ %s %s present", t.name, t.requested)
		print_optional_version(t.version)
		return
	}
	if t.status == "present" {
		fmt.printf("  ! %s %s mismatch", t.name, t.requested)
		print_optional_version(t.version)
		return
	}
	if t.status == "missing" {
		fmt.printf("  ! %s %s missing\n", t.name, t.requested)
		return
	}
	fmt.printf("  ! %s %s unsupported\n", t.name, t.requested)
}

print_optional_version :: proc(version: string) {
	if version != "" {
		fmt.printf(" (%s)", version)
	}
	fmt.println("")
}

print_file_checks :: proc(title: string, checks: []File_Check) {
	if len(checks) == 0 {
		return
	}
	fmt.println("")
	fmt.println(title)
	for c in checks {
		mark := "✓"
		status := ""
		if c.status != "present" {
			mark = "!"
			status = " missing"
		}
		if c.kind == "compose" {
			fmt.printf("  %s compose %s%s\n", mark, c.path, status)
		} else {
			fmt.printf("  %s %s %s%s\n", mark, c.kind, c.path, status)
		}
	}
}

print_dependency_checks :: proc(dependency_checks: []Dependency_Check) {
	if len(dependency_checks) == 0 {
		return
	}
	fmt.println("")
	fmt.println("Dependencies")
	for c in dependency_checks {
		if c.status == "present" {
			fmt.printf("  ✓ %s dependencies present (%s)\n", c.runner, c.path)
		} else {
			fmt.printf("  ! %s dependencies missing (%s)\n", c.runner, c.path)
		}
	}
}

print_script_groups :: proc(cfg: Project_Config) {
	for group in cfg.script_groups {
		if len(group.scripts) == 0 {
			continue
		}
		fmt.println("")
		fmt.printf("Scripts %s\n", group.runner)
		for s in group.scripts {
			fmt.printf("  ✓ %s\n", s)
		}
	}
}

print_ready :: proc(cfg: Project_Config) {
	fmt.println("")
	fmt.println("Ready")
	script, ok := first_script(cfg)
	if ok {
		fmt.printf("  tyx run %s\n", quote_if_needed(script))
		return
	}
	fmt.println("  project.tyx parsed successfully")
}

print_fixes :: proc(resolved_tools: []Resolved_Tool, compose_checks: []File_Check, env_checks: []File_Check, dependency_checks: []Dependency_Check) {
	printed := false
	print_tool_fixes(resolved_tools, &printed)
	print_compose_fixes(compose_checks, &printed)
	print_env_fixes(env_checks, &printed)
	print_dependency_fixes(dependency_checks, &printed)
}

print_fix_header :: proc(printed: ^bool) {
	if printed^ {
		return
	}
	fmt.println("")
	fmt.println("Fix")
	printed^ = true
}

print_tool_fixes :: proc(resolved_tools: []Resolved_Tool, printed: ^bool) {
	for t in resolved_tools {
		if t.status == "present" && t.matches {
			continue
		}
		print_fix_header(printed)
		if t.status == "missing" {
			fmt.printf("  Install %s %s or make it available on PATH.\n", t.name, t.requested)
		} else if t.status == "present" {
			fmt.printf("  Use %s %s; found %s on PATH.\n", t.name, t.requested, t.version)
		} else {
			fmt.printf("  Tool %s is not supported by Tyx tool detection yet.\n", t.name)
		}
	}
}

print_compose_fixes :: proc(compose_checks: []File_Check, printed: ^bool) {
	for c in compose_checks {
		if c.status == "present" {
			continue
		}
		print_fix_header(printed)
		fmt.printf("  Restore compose file %s or remove it from project.tyx.\n", c.path)
	}
}

print_env_fixes :: proc(env_checks: []File_Check, printed: ^bool) {
	for c in env_checks {
		if c.status == "present" {
			continue
		}
		print_fix_header(printed)
		if c.kind == "file" {
			fmt.printf("  Create %s or remove it from project.tyx.\n", c.path)
		} else {
			fmt.printf("  Restore env example %s or remove it from project.tyx.\n", c.path)
		}
	}
}

print_dependency_fixes :: proc(dependency_checks: []Dependency_Check, printed: ^bool) {
	for c in dependency_checks {
		if c.status == "present" {
			continue
		}
		print_fix_header(printed)
		fmt.printf("  Run %s install to create %s.\n", c.runner, c.path)
	}
}
