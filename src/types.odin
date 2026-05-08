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
    script_runner: string,
    scripts:       [dynamic]string,
}

Tool :: struct {
    name:    string,
    version: string,
}

Repo_Info :: struct {
    node:                    string,
    package_manager:         string,
    package_manager_version: string,
    scripts:                 [dynamic]string,
    compose_files:           [dynamic]string,
    has_env_example:         bool,
}
