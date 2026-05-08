# Odin spike plan

Purpose: decide whether Odin is practical for Tyx before committing to full implementation.

## Pass criteria

The spike passes if an Odin implementation can stay small and pleasant while proving:

1. `tyx` builds as a standalone macOS binary.
2. Linux build path is verified or clearly documented.
3. `project.tyx` parser handles MVP syntax:
   - indentation-agnostic sections
   - comments and blank lines
   - header qualifiers
   - quoted tokens
   - `:` inside tokens
4. Repo scanner handles Node/TypeScript MVP fixtures:
   - `package.json#packageManager`
   - `package.json#engines.node`
   - `.nvmrc`
   - compose files
   - `.env.example`
   - package scripts including `db:migrate` and quoted names
5. Pretty structured output works without mandatory color.
6. Subprocess execution works for a simple command.
7. `tyx init` writes `project.tyx` matching fixture goldens.
8. `tyx up --spike` or equivalent writes a plausible `tyx.lock` without doing dangerous installs.
9. Basic fixture/golden testing is possible without a large framework.

## Stop criteria

Switch away from Odin if any of these become the dominant work:

- cross-platform build/distribution is fragile
- string parsing or JSON handling becomes too expensive
- subprocess handling is awkward
- testing/golden fixtures are painful
- the code becomes obscure enough that contributors will struggle

Fallback order:

1. Go, if speed and standalone pragmatism are the priority.
2. Rust, if maturity, libraries, and long-term system-tool safety become more important.

## Spike CLI

The spike should implement only:

```sh
tyx init [path]
tyx parse [project.tyx]
tyx run echo hello
```

`parse` is allowed during the spike but should not be part of MVP launch CLI.

## Expected `tyx init` output

```txt
Tyx initialized this repo

Wrote
  ✓ project.tyx

Detected
  ✓ node 22              package.json#engines.node
  ✓ pnpm 9.15.0          package.json#packageManager
  ✓ env example          .env.example
  ✓ scripts              dev, test, lint, build, db:migrate, "dev server"

Next
  tyx up
  tyx run dev
```

## Implementation notes

Keep implementation intentionally boring:

- no terminal UI framework
- no network calls
- no package installation in spike
- no Docker orchestration in spike
- no Nix/Devbox/mise integration in spike
- no arbitrary config execution

## Spike result notes

Initial local result after installing Odin via Homebrew:

- Odin version: `/opt/homebrew/bin/odin version dev-2026-05:ea5175d86`.
- macOS arm64 build works: `odin build src -out:bin/tyx`.
- Produced binary size in spike: ~468 KiB.
- Implemented spike commands:
  - `tyx init [path]`
  - `tyx parse [project.tyx]`
  - `tyx run <command> [args...]`
- `project.tyx` parser handles indentation-agnostic sections, header qualifiers, comments, quoted tokens, and `:` in script names.
- Node fixture scanning works for `package.json`, `packageManager`, `engines.node`, `.nvmrc`, Compose files, `.env.example`, and package scripts.
- Golden fixture diffs pass for `fixtures/node-basic` and `fixtures/node-compose`.
- Subprocess execution works via `tyx run echo hello`.

Linux note:

- Local macOS-to-Linux direct link failed with Odin's current message: `Linking for cross compilation for this platform is not yet supported (linux amd64)`.
- This does not fail Odin viability by itself, but Linux release builds likely need Linux CI or a Linux builder rather than local macOS cross-linking.
