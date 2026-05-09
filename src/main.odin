package main

import "core:fmt"
import "core:os"

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
		return cmd_init(command_path_arg(args, "."))
	case "up":
		return cmd_up(command_path_arg(args, "."))
	case "down":
		return cmd_down(command_path_arg(args, "."))
	case "parse":
		return cmd_parse(command_path_arg(args, "project.tyx"))
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
	path := "."
	first_arg := 2
	if len(args) >= 4 && args[2] == "--path" {
		path = args[3]
		first_arg = 4
	}
	if len(args) <= first_arg {
		fmt.println("Fix\n  Usage: tyx run [--path <path>] <script|command> [args...]")
		return false
	}
	return cmd_run(path, args[first_arg:])
}
