package main

import "core:strings"

TOOL_STATUS_PRESENT :: "present"
TOOL_STATUS_MISSING :: "missing"
TOOL_STATUS_UNSUPPORTED :: "unsupported"
TOOL_PROVIDER_PATH :: "path"

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
		append(&resolved, resolve_tool(t))
	}
	return resolved
}

resolve_tool :: proc(t: Tool) -> Resolved_Tool {
	result := Resolved_Tool{name = t.name, requested = t.version, status = TOOL_STATUS_MISSING, provider = TOOL_PROVIDER_PATH}
	command := tool_version_command(t.name)
	if len(command) == 0 {
		result.status = TOOL_STATUS_UNSUPPORTED
		return result
	}
	process := run_command_capture(command)
	if process_succeeded(process) {
		result.status = TOOL_STATUS_PRESENT
		result.version = first_line(string(process.stdout))
		result.matches = version_matches(t.version, result.version)
		return result
	}
	if process.err == nil && len(process.stderr) > 0 {
		result.version = first_line(string(process.stderr))
	}
	return result
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
	if trimmed == "" {
		return ""
	}
	parts := strings.split(trimmed, "\n")
	return strings.trim_space(parts[0])
}

version_matches :: proc(requested, actual: string) -> bool {
	if requested == "" || requested == "latest" {
		return true
	}
	req_major, req_ok := leading_major(requested)
	if !req_ok {
		return requested == actual
	}
	actual_major, actual_ok := leading_major(actual)
	if !actual_ok {
		return false
	}
	return req_major == actual_major
}

leading_major :: proc(s: string) -> (string, bool) {
	trimmed := strings.trim_space(s)
	i := 0
	for i < len(trimmed) && !is_digit(trimmed[i]) {
		i += 1
	}
	start := i
	for i < len(trimmed) && is_digit(trimmed[i]) {
		i += 1
	}
	if start == i {
		return "", false
	}
	return trimmed[start:i], true
}

is_digit :: proc(b: byte) -> bool {
	return b >= '0' && b <= '9'
}
