package main

import "core:fmt"
import "core:os"

run_command :: proc(command: []string, working_dir: string) -> bool {
	state, stdout, stderr, err := run_command_capture(command, working_dir)
	print_process_output(stdout, stderr)
	return process_succeeded(state, err)
}

run_command_capture :: proc(command: []string, working_dir := "") -> (os.Process_State, []byte, []byte, os.Error) {
	desc := os.Process_Desc{command = command, working_dir = working_dir}
	return os.process_exec(desc, context.allocator)
}

process_succeeded :: proc(state: os.Process_State, err: os.Error) -> bool {
	return err == nil && state.exited && state.exit_code == 0
}

print_process_output :: proc(stdout, stderr: []byte) {
	if len(stdout) > 0 {
		fmt.print(string(stdout))
	}
	if len(stderr) > 0 {
		fmt.eprint(string(stderr))
	}
}
