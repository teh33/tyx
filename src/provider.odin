package main

import "core:os"
import "core:strings"

Resolved_Tool :: struct {
    name:      string,
    requested: string,
    status:    string,
    provider:  string,
    version:   string,
    matches:   bool,
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
            result.matches = version_matches(t.version, result.version)
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

version_matches :: proc(requested, actual: string) -> bool {
    if requested == "" || requested == "latest" do return true
    req_major, req_ok := leading_major(requested)
    if !req_ok do return requested == actual
    actual_major, actual_ok := leading_major(actual)
    if !actual_ok do return false
    return req_major == actual_major
}

leading_major :: proc(s: string) -> (string, bool) {
    trimmed := strings.trim_space(s)
    i := 0
    for i < len(trimmed) && (trimmed[i] < '0' || trimmed[i] > '9') do i += 1
    start := i
    for i < len(trimmed) && trimmed[i] >= '0' && trimmed[i] <= '9' do i += 1
    if start == i do return "", false
    return trimmed[start:i], true
}
