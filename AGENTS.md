# AGENTS.md — Tyx

Tyx is Tiny Nix for repo dev environments: a small native CLI plus `project.tyx` language for inferring, locking, and reproducing project tools, services, env files, and scripts.

## Current scope

MVP commands:

- `tyx init [path]`
- `tyx up [path]`
- `tyx run [--path <path>] <script|command> [args...]`

Launch target: ordinary Node/TypeScript repos on macOS and Linux. Keep the internal model language-agnostic.

## Build and verify

Use Zig. Verify before reporting success:

```sh
./scripts/verify
```

The verify script builds `bin/tyx`, checks fixture goldens, runs `tyx up`, parses `project.tyx`, and smoke-tests subprocess execution.

## Design constraints

- Keep Tyx standalone: zero runtime dependencies.
- Keep CLI surface small; do not add commands without a strong reason.
- Normal commands should be non-interactive and agent-friendly.
- Default output should be pretty, structured, deterministic, and not rely on color.
- Prefer `Fix` diagnostics for actionable local problems; reserve `Unsupported` for real unsupported capabilities.
- Do not execute arbitrary code from `project.tyx`.
- Keep `project.tyx` tiny, declarative, indentation-agnostic, and line-oriented.
- Generated fixture files (`project.tyx`, `tyx.lock`) should not remain as untracked noise after verification.

## Source layout

- `src/main.zig` — CLI dispatch and command orchestration
- `src/types.zig` — shared data model
- `src/runtime.zig` — I/O, file, process, and path helpers
- `src/parser.zig` — `project.tyx` parser
- `src/repo_scan.zig` — repo inference
- `src/render.zig` — `project.tyx` and `tyx.lock` rendering
- `src/output.zig` — structured user-facing output
