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
	if !ok {
		return false
	}
	if !write_file(out_path, render_project(info)) {
		return false
	}
	print_init_success(info)
	return true
}

cmd_up :: proc(path: string) -> bool {
	cfg, ok := load_project_config(join2(path, "project.tyx"))
	if !ok {
		return false
	}
	state := prepare_project(path, cfg)
	if !write_file(join2(path, "tyx.lock"), render_lock(cfg, state.tools[:], state.compose_files[:], state.env_files[:], state.dependencies[:])) {
		return false
	}
	print_up_success(cfg, state.tools[:], state.compose_files[:], state.env_files[:], state.dependencies[:])
	return state.install_ok && state.compose_ok
}

cmd_down :: proc(path: string) -> bool {
	cfg, ok := load_project_config(join2(path, "project.tyx"))
	if !ok {
		return false
	}
	compose_checks := check_compose_files(path, cfg)
	print_down_start(compose_checks[:])
	return compose_down(path, compose_checks[:])
}

cmd_parse :: proc(path: string) -> bool {
	cfg, ok := load_project_config(path)
	if !ok {
		return false
	}
	print_parsed_config(cfg)
	return true
}

cmd_run :: proc(path: string, args: []string) -> bool {
	command := resolve_run_command(path, args)
	if !run_command(command, path) {
		fmt.println("Fix")
		fmt.println("  Command failed.")
		return false
	}
	return true
}

prepare_project :: proc(path: string, cfg: Project_Config) -> Up_State {
	state := Up_State{
		tools = resolve_tools(cfg),
		compose_files = check_compose_files(path, cfg),
		env_files = check_env_files(path, cfg),
		dependencies = check_dependencies(path, cfg),
		install_ok = true,
		compose_ok = true,
	}
	_, state.install_ok = install_missing_dependencies(path, state.dependencies[:])
	state.dependencies = check_dependencies(path, cfg)
	state.compose_ok = compose_up(path, state.compose_files[:])
	return state
}

load_project_config :: proc(path: string) -> (Project_Config, bool) {
	cfg: Project_Config
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.printf("Fix\n  Could not read %s: %v\n", path, err)
		return cfg, false
	}
	entries, ok := parse_tyx(string(bytes))
	if !ok {
		return cfg, false
	}
	return config_from_entries(entries[:]), true
}

resolve_run_command :: proc(path: string, args: []string) -> []string {
	project_path := join2(path, "project.tyx")
	if os.is_file(project_path) {
		cfg, ok := load_project_config(project_path)
		if ok {
			if resolved, found := resolve_script(cfg, args[0]); found {
				return resolved
			}
		}
	}
	return args
}

write_file :: proc(path, contents: string) -> bool {
	if err := os.write_entire_file(path, contents); err != nil {
		fmt.printf("Fix\n  Could not write %s: %v\n", path, err)
		return false
	}
	return true
}
