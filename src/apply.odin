package main

import "core:fmt"

INSTALL_STATUS_INSTALLED :: "installed"
INSTALL_STATUS_FAILED :: "failed"
COMPOSE_ACTION_UP :: "up"
COMPOSE_ACTION_DOWN :: "down"

Install_Result :: struct {
	runner: string,
	status: string,
}

install_missing_dependencies :: proc(root: string, dependency_checks: []Dependency_Check) -> ([dynamic]Install_Result, bool) {
	results: [dynamic]Install_Result
	ok := true
	for check in dependency_checks {
		if check.status == FILE_STATUS_PRESENT {
			continue
		}
		result := install_dependencies(root, check.runner)
		append(&results, result)
		if result.status == INSTALL_STATUS_FAILED {
			ok = false
		}
	}
	return results, ok
}

install_dependencies :: proc(root, runner: string) -> Install_Result {
	fmt.println("")
	fmt.println("Installing")
	fmt.printf("  → %s install\n", runner)
	if !run_command([]string{runner, "install"}, root) {
		fmt.printf("Fix\n  `%s install` failed. Resolve the package manager error and run `tyx up` again.\n", runner)
		return Install_Result{runner = runner, status = INSTALL_STATUS_FAILED}
	}
	return Install_Result{runner = runner, status = INSTALL_STATUS_INSTALLED}
}

compose_up :: proc(root: string, compose_checks: []File_Check) -> bool {
	return compose_run(root, compose_checks, COMPOSE_ACTION_UP, true)
}

compose_down :: proc(root: string, compose_checks: []File_Check) -> bool {
	return compose_run(root, compose_checks, COMPOSE_ACTION_DOWN, false)
}

compose_run :: proc(root: string, compose_checks: []File_Check, action: string, detached: bool) -> bool {
	command := compose_command(compose_checks, action, detached)
	if len(command) == 0 {
		return true
	}
	print_compose_action(action)
	if !run_command(command, root) {
		print_compose_failure(action)
		return false
	}
	return true
}

print_compose_action :: proc(action: string) {
	if action == COMPOSE_ACTION_UP {
		fmt.println("")
		fmt.println("Starting")
		fmt.println("  → docker compose up -d")
		return
	}
	fmt.println("Stopping")
	fmt.println("  → docker compose down")
}

print_compose_failure :: proc(action: string) {
	fmt.println("Fix")
	if action == COMPOSE_ACTION_UP {
		fmt.println("  `docker compose up -d` failed. Resolve the Docker error and run `tyx up` again.")
		return
	}
	fmt.println("  `docker compose down` failed. Resolve the Docker error and run `tyx down` again.")
}

compose_command :: proc(compose_checks: []File_Check, action: string, detached: bool) -> []string {
	present_count := count_present_files(compose_checks)
	if present_count == 0 {
		return nil
	}
	command := make_compose_command(present_count, detached)
	write_compose_command(command, compose_checks, action, detached)
	return command
}

count_present_files :: proc(checks: []File_Check) -> int {
	count := 0
	for check in checks {
		if check.status == FILE_STATUS_PRESENT {
			count += 1
		}
	}
	return count
}

make_compose_command :: proc(present_count: int, detached: bool) -> []string {
	extra := 1
	if detached {
		extra = 2
	}
	return make([]string, 2 + present_count*2 + extra)
}

write_compose_command :: proc(command: []string, compose_checks: []File_Check, action: string, detached: bool) {
	i := 0
	command[i] = "docker"
	i += 1
	command[i] = "compose"
	i += 1
	for check in compose_checks {
		if check.status != FILE_STATUS_PRESENT {
			continue
		}
		command[i] = "-f"
		i += 1
		command[i] = check.path
		i += 1
	}
	command[i] = action
	i += 1
	if detached {
		command[i] = "-d"
	}
}
