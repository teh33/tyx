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

compose_down :: proc(root: string, compose_checks: []File_Check) -> bool {
    command := compose_command(compose_checks, "down", false)
    if len(command) == 0 do return true

    fmt.println("Stopping")
    fmt.println("  → docker compose down")

    desc := os.Process_Desc{command = command, working_dir = root}
    state, stdout, stderr, err := os.process_exec(desc, context.allocator)
    if len(stdout) > 0 do fmt.print(string(stdout))
    if len(stderr) > 0 do fmt.eprint(string(stderr))
    if err != nil || !state.exited || state.exit_code != 0 {
        fmt.println("Fix")
        fmt.println("  `docker compose down` failed. Resolve the Docker error and run `tyx down` again.")
        return false
    }
    return true
}

compose_command :: proc(compose_checks: []File_Check, action: string, detached: bool) -> []string {
    present_count := 0
    for c in compose_checks {
        if c.status == "present" do present_count += 1
    }
    if present_count == 0 do return nil

    extra := 1
    if detached do extra = 2
    command := make([]string, 2 + present_count*2 + extra)
    i := 0
    command[i] = "docker"
    i += 1
    command[i] = "compose"
    i += 1
    for c in compose_checks {
        if c.status != "present" do continue
        command[i] = "-f"
        i += 1
        command[i] = c.path
        i += 1
    }
    command[i] = action
    i += 1
    if detached do command[i] = "-d"
    return command
}

compose_up :: proc(root: string, compose_checks: []File_Check) -> bool {
    command := compose_command(compose_checks, "up", true)
    if len(command) == 0 do return true

    fmt.println("")
    fmt.println("Starting")
    fmt.println("  → docker compose up -d")

    desc := os.Process_Desc{command = command, working_dir = root}
    state, stdout, stderr, err := os.process_exec(desc, context.allocator)
    if len(stdout) > 0 do fmt.print(string(stdout))
    if len(stderr) > 0 do fmt.eprint(string(stderr))
    if err != nil || !state.exited || state.exit_code != 0 {
        fmt.println("Fix")
        fmt.println("  `docker compose up -d` failed. Resolve the Docker error and run `tyx up` again.")
        return false
    }
    return true
}
