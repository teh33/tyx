package main

import "core:fmt"
import "core:os"

Process_Result :: struct {
	state:  os.Process_State,
	stdout: []byte,
	stderr: []byte,
	err:    os.Error,
}

run_command :: proc(command: []string, working_dir: string) -> bool {
	result := run_command_capture(command, working_dir)
	print_process_output(result)
	return process_succeeded(result)
}

run_command_capture :: proc(command: []string, working_dir := "") -> Process_Result {
	desc := os.Process_Desc{command = command, working_dir = working_dir}
	state, stdout, stderr, err := os.process_exec(desc, context.allocator)
	return Process_Result{state = state, stdout = stdout, stderr = stderr, err = err}
}

process_succeeded :: proc(result: Process_Result) -> bool {
	return result.err == nil && result.state.exited && result.state.exit_code == 0
}

print_process_output :: proc(result: Process_Result) {
	if len(result.stdout) > 0 {
		fmt.print(string(result.stdout))
	}
	if len(result.stderr) > 0 {
		fmt.eprint(string(result.stderr))
	}
}
