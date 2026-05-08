# Tyx

Tyx is Tiny Nix for repo dev environments: a small native CLI and declarative `project.tyx` language for inferring, locking, and reproducing the tools, services, env files, and scripts needed to work on a project.

The first target is ordinary Node/TypeScript repos that do **not** already use Nix, Devbox, mise, or devcontainers.

```sh
git clone <repo>
cd <repo>
tyx init
tyx up
tyx run dev
```

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

## Status

Early Odin spike. Current working commands:

```sh
scripts/verify
```

Manual commands:

```sh
odin build src -out:bin/tyx
./bin/tyx init fixtures/node-basic
./bin/tyx up fixtures/node-basic
./bin/tyx parse fixtures/node-basic/expected.project.tyx
./bin/tyx run echo hello
```

Linux release builds likely need Linux CI/builders; local macOS-to-Linux linking is not supported by the installed Odin toolchain.
