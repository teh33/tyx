package main

import "core:os"
import "core:strings"

Resolved_Tool :: struct {
    name:      string,
    requested: string,
    status:    string,
    provider:  string,
    version:   string,
}

resolve_tools :: proc(cfg: Project_Config) -> [dynamic]Resolved_Tool {
    resolved: [dynamic]Resolved_Tool
    for t in cfg.tools {
        command := tool_version_command(t.name)
        result := Resolved_Tool{name = t.name, requested = t.version, status = "missing", provider = "path"}
        if len(command) == 0 {
            result.status = "unsupported"
            append(&resolved, result)
            continue
        }

        desc := os.Process_Desc{command = command}
        state, stdout, stderr, err := os.process_exec(desc, context.allocator)
        if err == nil && state.exited && state.exit_code == 0 {
            result.status = "present"
            result.version = first_line(string(stdout))
        } else if err == nil && len(stderr) > 0 {
            result.version = first_line(string(stderr))
        }
        append(&resolved, result)
    }
    return resolved
}

tool_version_command :: proc(name: string) -> []string {
    switch name {
    case "node", "npm", "pnpm", "yarn", "bun":
        command := make([]string, 2)
        command[0] = name
        command[1] = "--version"
        return command
    }
    return nil
}

first_line :: proc(s: string) -> string {
    trimmed := strings.trim_space(s)
    if trimmed == "" do return ""
    parts := strings.split(trimmed, "\n")
    return strings.trim_space(parts[0])
}
