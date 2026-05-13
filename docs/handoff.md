# Tyx Handoff

Tyx is now a Zig CLI for tiny repo dev environments.

## Current status

Canonical implementation:

- `src/main.zig` — CLI dispatch and command orchestration
- `src/types.zig` — shared data model
- `src/runtime.zig` — I/O, file, process, and path helpers
- `src/parser.zig` — `project.tyx` parser
- `src/repo_scan.zig` — repo inference
- `src/render.zig` — `project.tyx` and `tyx.lock` rendering
- `src/output.zig` — structured user-facing output

Verify before reporting success:

```sh
./scripts/verify
```

HN release validation is documented in `docs/hn-trial-results.md`.
