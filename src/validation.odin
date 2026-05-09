package main

import "core:fmt"

ENTRY_COMPOSE :: "compose"
ENTRY_ENV_EXAMPLE :: "example"
ENTRY_ENV_FILE :: "file"

validate_header :: proc(tokens: []string, line: int, seen_project: ^bool) -> bool {
	if len(tokens) == 0 {
		fmt.printf("Fix\n  Empty section header on line %d.\n", line)
		return false
	}
	section := tokens[0]
	switch section {
	case SECTION_PROJECT:
		return validate_project_header(tokens, line, seen_project)
	case SECTION_TOOLS, SECTION_SERVICES, SECTION_ENV:
		return validate_unqualified_header(section, tokens, line)
	case SECTION_SCRIPTS:
		return validate_scripts_header(tokens, line)
	case:
		fmt.printf("Unsupported\n  section `%s` on line %d is not supported.\n", section, line)
		fmt.println("")
		fmt.println("Fix\n  Use project:, tools:, services:, env:, or scripts <runner>:")
		return false
	}
}

validate_project_header :: proc(tokens: []string, line: int, seen_project: ^bool) -> bool {
	if len(tokens) != 1 {
		fmt.printf("Fix\n  `project:` does not accept qualifiers on line %d.\n", line)
		return false
	}
	seen_project^ = true
	return true
}

validate_unqualified_header :: proc(section: string, tokens: []string, line: int) -> bool {
	if len(tokens) == 1 {
		return true
	}
	fmt.printf("Unsupported\n  Qualified `%s` section on line %d is not supported yet.\n", section, line)
	fmt.println("")
	fmt.printf("Fix\n  Use `%s:` without qualifiers for the MVP.\n", section)
	return false
}

validate_scripts_header :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) != 2 {
		fmt.printf("Fix\n  `scripts` section on line %d needs exactly one runner.\n", line)
		fmt.println("")
		fmt.println("  Example: `scripts pnpm:`")
		return false
	}
	if !is_supported_runner(tokens[1]) {
		fmt.printf("Unsupported\n  script runner `%s` on line %d is not supported.\n", tokens[1], line)
		fmt.println("")
		fmt.println("Fix\n  Use npm, pnpm, yarn, bun, or a command available on PATH.")
		return false
	}
	return true
}

validate_entry :: proc(header, tokens: []string, line: int) -> bool {
	if len(tokens) == 0 {
		return true
	}
	switch header[0] {
	case SECTION_PROJECT:
		fmt.printf("Fix\n  `project:` does not accept entries; found one on line %d.\n", line)
		return false
	case SECTION_TOOLS:
		return validate_tool_entry(tokens, line)
	case SECTION_SERVICES:
		return validate_service_entry(tokens, line)
	case SECTION_ENV:
		return validate_env_entry(tokens, line)
	case SECTION_SCRIPTS:
		return validate_script_entry(tokens, line)
	}
	return true
}

validate_tool_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) != 2 {
		fmt.printf("Fix\n  Tool entry on line %d must be `<tool> <version>`.\n", line)
		fmt.println("")
		fmt.println("  Example: `node 22`")
		return false
	}
	if !is_supported_tool(tokens[0]) {
		fmt.printf("Unsupported\n  tool `%s` on line %d is not supported yet.\n", tokens[0], line)
		fmt.println("")
		fmt.println("Fix\n  Use node, npm, pnpm, yarn, or bun for the MVP.")
		return false
	}
	return true
}

validate_service_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) == 2 && tokens[0] == ENTRY_COMPOSE {
		return true
	}
	fmt.printf("Fix\n  Service entry on line %d must be `compose <file>`.\n", line)
	fmt.println("")
	fmt.println("  Example: `compose compose.yaml`")
	return false
}

validate_env_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) == 2 && (tokens[0] == ENTRY_ENV_EXAMPLE || tokens[0] == ENTRY_ENV_FILE) {
		return true
	}
	fmt.printf("Fix\n  Env entry on line %d must be `example <file>` or `file <file>`.\n", line)
	return false
}

validate_script_entry :: proc(tokens: []string, line: int) -> bool {
	if len(tokens) == 1 {
		return true
	}
	fmt.printf("Fix\n  Script entry on line %d must be one script name.\n", line)
	fmt.println("\n  Quote names that contain spaces, e.g. `\"dev server\"`.")
	return false
}

is_supported_tool :: proc(name: string) -> bool {
	return name == "node" || name == "npm" || name == "pnpm" || name == "yarn" || name == "bun"
}

is_supported_runner :: proc(name: string) -> bool {
	// MVP accepts Node package runners and simple command runners used by fixtures.
	return is_supported_tool(name) || name == "echo"
}
