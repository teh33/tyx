package main

import "core:fmt"
import "core:os"

DEFAULT_PROJECT_PATH :: "."
DEFAULT_PARSE_PATH :: "project.tyx"
RUN_PATH_FLAG :: "--path"

main :: proc() {
	args := os.args
	if len(args) < 2 {
		print_usage()
		os.exit(1)
	}
	if !dispatch(args) {
		os.exit(1)
	}
}

dispatch :: proc(args: []string) -> bool {
	switch args[1] {
	case "init":
		return cmd_init(command_path_arg(args, DEFAULT_PROJECT_PATH))
	case "up":
		return cmd_up(command_path_arg(args, DEFAULT_PROJECT_PATH))
	case "down":
		return cmd_down(command_path_arg(args, DEFAULT_PROJECT_PATH))
	case "parse":
		return cmd_parse(command_path_arg(args, DEFAULT_PARSE_PATH))
	case "run":
		return dispatch_run(args)
	case:
		print_usage()
		return false
	}
}

command_path_arg :: proc(args: []string, default_path: string) -> string {
	if len(args) >= 3 {
		return args[2]
	}
	return default_path
}

dispatch_run :: proc(args: []string) -> bool {
	path, first_arg := run_args(args)
	if len(args) <= first_arg {
		fmt.println("Fix\n  Usage: tyx run [--path <path>] <script|command> [args...]")
		return false
	}
	return cmd_run(path, args[first_arg:])
}

run_args :: proc(args: []string) -> (string, int) {
	if len(args) >= 4 && args[2] == RUN_PATH_FLAG {
		return args[3], 4
	}
	return DEFAULT_PROJECT_PATH, 2
}
