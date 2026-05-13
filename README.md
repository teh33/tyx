# Tyx

Tyx is Tiny Nix for repo dev environments: a small standalone native CLI and declarative `project.tyx` file for inferring, locking, and reproducing the tools, services, env files, and scripts needed to work on a project.

It is **not** a Nix replacement. Tyx starts with ordinary repos that already imply their setup through files like `package.json`, Node version hints, package-manager lockfiles, Compose files, and `.env.example`; then it writes a reviewable `project.tyx` and applies setup by delegating to existing tools.

The first target is ordinary Node/TypeScript repos that do **not** already use Nix, Devbox, mise, or devcontainers.

```sh
git clone <repo>
cd <repo>
tyx init       # infer repo setup and write project.tyx
tyx up         # install dependencies, start declared services, write tyx.lock
tyx run dev    # run a script inside the Tyx environment
```

## Install / build

Build from source:

```sh
zig build
./bin/tyx init fixtures/node-basic
./bin/tyx up fixtures/node-basic
./bin/tyx run echo hello
```

Run the full local verification gate:

```sh
./scripts/verify
```

Release binaries are planned for macOS and Linux.

## MVP commands

- `tyx init` — inspect the current repo and write `project.tyx`.
- `tyx up` — read `project.tyx`, resolve/provision the environment, write `tyx.lock`, install dependencies, and start services.
- `tyx run <script|command>` — run a configured script or command inside the Tyx environment.

No prompts are required in the normal path. Output is structured and human-friendly by default so it remains useful for agents without a separate JSON mode.

## Example `project.tyx`

```tyx
project:

tools:
node 22
pnpm 9.15.0

services:
compose compose.yaml
compose compose.override.yaml

env:
example .env.example
file .env

scripts pnpm:
dev
test
lint
build
db:migrate
"dev server"
```

Indented and unindented entries parse the same.

## Demo

Try the MVP flow on the included fixture:

```sh
./scripts/verify
./bin/tyx init fixtures/node-basic
./bin/tyx up fixtures/node-basic
./bin/tyx run echo hello
```

## Comparison

| Tool | Best at | How Tyx differs |
| --- | --- | --- |
| Nix flakes | Deep reproducibility and pinned package graphs | Tyx does not claim Nix-level hermeticity; it optimizes for low-friction repo inference and delegated setup. |
| Devbox | Nix-backed reproducible packages with simpler config | Tyx starts by inferring ordinary repos and generating `project.tyx`; Nix-like tools can become providers later. |
| mise/asdf | Installing and activating runtime/tool versions | Tyx can delegate to these; it adds repo inference, services/env/scripts, lock metadata, and structured setup output. |
| devcontainers/Codespaces | Containerized/cloud IDE environments | Tyx targets native local setup first and can detect or delegate to containers later. |
| Docker Compose | Local service orchestration | Tyx detects Compose files and starts declared services; it does not replace Compose. |

## Limitations and safety

- MVP target is ordinary Node/TypeScript repos.
- `tyx init` is safe/static: it reads repo files and writes `project.tyx`; it does not install packages, start Docker, read env secrets, or run project scripts.
- `tyx up` is the explicit apply command: it may run package-manager install commands and declared Docker Compose startup, printing commands before execution.
- Tyx does not install system packages in the MVP.
- `tyx.lock` is resolved setup metadata, not a hermetic Nix-style lockfile.
- Package-manager lockfiles remain the source of truth for dependency graphs.
- Docker image digests are not normalized in the MVP.
- Output is non-interactive, sectioned, deterministic, and does not require color or JSON.

## Docs

- `docs/project-tyx-language.md` — MVP `project.tyx` syntax.
- `docs/tyx-lock.md` — MVP `tyx.lock` metadata and update policy.
- `docs/hn-trial-results.md` — validation evidence from trialing Tyx on 10 GitHub repos.
- `docs/handoff.md` — current implementation handoff.

## Status

Current working commands:

```sh
scripts/verify
```

Manual commands:

```sh
zig build
./bin/tyx init fixtures/node-basic
./bin/tyx up fixtures/node-basic
./bin/tyx parse fixtures/node-basic/expected.project.tyx
./bin/tyx run echo hello
```

