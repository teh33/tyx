package main

config_from_entries :: proc(entries: []Entry) -> Project_Config {
	cfg: Project_Config
	for e in entries {
		if len(e.header) == 0 {
			continue
		}
		add_entry_to_config(&cfg, e)
	}
	return cfg
}

add_entry_to_config :: proc(cfg: ^Project_Config, entry: Entry) {
	section := entry.header[0]
	switch section {
	case SECTION_TOOLS:
		append(&cfg.tools, Tool{name = entry.tokens[0], version = entry.tokens[1]})
	case SECTION_SERVICES:
		append(&cfg.compose_files, entry.tokens[1])
	case SECTION_ENV:
		add_env_entry(cfg, entry.tokens[0], entry.tokens[1])
	case SECTION_SCRIPTS:
		add_script(cfg, entry.header[1], entry.tokens[0])
	}
}

add_env_entry :: proc(cfg: ^Project_Config, kind, path: string) {
	if kind == "example" {
		append(&cfg.env_examples, path)
		return
	}
	if kind == "file" {
		append(&cfg.env_files, path)
	}
}

add_script :: proc(cfg: ^Project_Config, runner, script: string) {
	idx := find_script_group(cfg, runner)
	if idx < 0 {
		group := Script_Group{runner = runner}
		append(&group.scripts, script)
		append(&cfg.script_groups, group)
		return
	}
	append(&cfg.script_groups[idx].scripts, script)
}

find_script_group :: proc(cfg: ^Project_Config, runner: string) -> int {
	for group, i in cfg.script_groups {
		if group.runner == runner {
			return i
		}
	}
	return -1
}
