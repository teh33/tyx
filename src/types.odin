package main

Entry :: struct {
	header: []string,
	tokens: []string,
	line:   int,
}

Project_Config :: struct {
	tools:         [dynamic]Tool,
	compose_files: [dynamic]string,
	env_examples:  [dynamic]string,
	env_files:     [dynamic]string,
	script_groups: [dynamic]Script_Group,
}

Script_Group :: struct {
	runner:  string,
	scripts: [dynamic]string,
}

Tool :: struct {
	name:    string,
	version: string,
}

Dependency_Check :: struct {
	runner:   string,
	manifest: string,
	path:     string,
	status:   string,
}

Repo_Info :: struct {
	node:                    string,
	package_manager:         string,
	package_manager_version: string,
	scripts:                 [dynamic]string,
	compose_files:           [dynamic]string,
	has_env_example:         bool,
	has_env_file:            bool,
}

Up_State :: struct {
	tools:         [dynamic]Resolved_Tool,
	compose_files: [dynamic]File_Check,
	env_files:     [dynamic]File_Check,
	dependencies:  [dynamic]Dependency_Check,
	install_ok:    bool,
	compose_ok:    bool,
}
