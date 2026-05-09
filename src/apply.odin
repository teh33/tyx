package main

import "core:fmt"
import "core:os"

Install_Result :: struct {
    runner: string,
    status: string,
}

install_missing_dependencies :: proc(root: string, dependency_checks: []Dependency_Check) -> ([dynamic]Install_Result, bool) {
    results: [dynamic]Install_Result
    ok := true

    for c in dependency_checks {
        if c.status == "present" do continue

        fmt.println("")
        fmt.println("Installing")
        fmt.printf("  → %s install\n", c.runner)

        command := make([]string, 2)
        command[0] = c.runner
        command[1] = "install"
        desc := os.Process_Desc{command = command, working_dir = root}
        state, stdout, stderr, err := os.process_exec(desc, context.allocator)

        if len(stdout) > 0 do fmt.print(string(stdout))
        if len(stderr) > 0 do fmt.eprint(string(stderr))

        if err != nil || !state.exited || state.exit_code != 0 {
            fmt.printf("Fix\n  `%s install` failed. Resolve the package manager error and run `tyx up` again.\n", c.runner)
            append(&results, Install_Result{runner = c.runner, status = "failed"})
            ok = false
            continue
        }

        append(&results, Install_Result{runner = c.runner, status = "installed"})
    }

    return results, ok
}
