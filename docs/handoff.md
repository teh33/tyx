# Tyx handoff

Current build contract:

- Product frame: Tiny Nix for repo dev environments.
- MVP commands: `tyx init`, `tyx up`, `tyx run`.
- MVP file: `project.tyx`.
- Lockfile: `tyx.lock`.
- Launch target: Node/TypeScript repos on macOS + Linux.
- Implementation decision: run Odin spike first; Go/Rust remain fallbacks.
- CLI output: pretty structured by default, stable enough for agents, no required `--json`.
- Interaction model: no mandatory prompts; `tyx init` refuses to overwrite existing `project.tyx` unless a future force flag is used.

Important docs:

- `docs/project-tyx-language.md` — MVP language spec.
- `docs/odin-spike-plan.md` — Odin viability spike contract.
- `fixtures/*/expected.project.tyx` — first golden outputs for `tyx init`.

## Odin spike status

An initial Odin spike now exists in `src/main.odin`.

Working commands:

```sh
odin build src -out:bin/tyx
./bin/tyx init fixtures/node-basic
./bin/tyx parse fixtures/node-basic/project.tyx
./bin/tyx run echo hello
```

Known limitation: local macOS-to-Linux cross-linking failed, so Linux artifacts should be produced on Linux CI/builders unless a better Odin cross-link setup is found.


## Source layout

- `src/main.odin` — CLI dispatch.
- `src/types.odin` — shared data structures.
- `src/parser.odin` — `project.tyx` parser and config model conversion.
- `src/repo_scan.odin` — Node/TypeScript repo inference.
- `src/render.odin` — `project.tyx` generation.
- `src/output.odin` — structured human/agent-friendly output.
- `src/commands.odin` — command implementations.
- `src/util.odin` — small shared helpers.
- `scripts/verify` — build + fixture golden verification.


## `tyx up` skeleton

`tyx up [path]` now reads `project.tyx`, writes a conservative `tyx.lock`, and prints structured output. It does not install packages, activate runtimes, or start Docker Compose yet. That provider work should come after lock semantics are firmed up.
