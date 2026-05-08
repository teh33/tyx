# `project.tyx` MVP language

`project.tyx` is Tyx's project environment file. It is intentionally tiny: declarative, line-oriented, indentation-agnostic, easy to generate, easy to parse, and stable enough for agents.

## Goals

- Describe a repo's local development environment.
- Stay small enough to parse in a standalone native CLI.
- Be readable without learning Nix, YAML, or a programming language.
- Preserve a future path toward `home.tyx`, `machine.tyx`, and system-level Tyx files.

## Non-goals

- Arbitrary code execution.
- Shell scripting.
- Full package/build language semantics.
- YAML/TOML compatibility.
- Hermetic builds in the MVP.

## Example

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

Equivalent with indentation:

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

## Parsing model

- Input is UTF-8 text.
- Blank lines are ignored.
- Leading indentation is ignored.
- A comment is a line whose first non-whitespace character is `#`.
- A header is a non-comment line ending with `:` outside quotes.
- Header grammar: `<section> [qualifier...]:`.
- Entries belong to the most recent header until the next header.
- Entries are tokenized by whitespace, with quoted tokens supported.
- `:` inside a token is allowed; only a trailing `:` outside quotes marks a header.
- Quoted tokens support `\"` and `\\` escapes in MVP.

## MVP headers

### `project:`

Marks the file as a project Tyx file. It has no required entries in MVP.

### `tools:`

Declares required development tools and requested versions.

```tyx
tools:
node 22
pnpm 9.15.0
```

Version semantics are tool-specific. For Node, `22` means the Node 22 major line. `tyx.lock` records the resolved exact version.

### `services:`

Declares local services. MVP supports Docker Compose pass-through.

```tyx
services:
compose compose.yaml
compose compose.override.yaml
```

Repeated `compose` lines are applied together in order, equivalent to passing multiple `-f` files to Docker Compose.

### `env:`

Declares environment file expectations without reading secrets as config.

```tyx
env:
example .env.example
file .env
```

`example` records a template file. `file` records the expected local env file. If the expected file is missing, `tyx up` should print a `Fix` section rather than reading secrets or creating guesses.

### `scripts <runner>:`

Declares scripts runnable through a package/script runner.

```tyx
scripts pnpm:
dev
test
db:migrate
"dev server"
```

`tyx run dev` runs `pnpm dev`. Quoted script names are supported in MVP so Tyx can represent unusual package scripts without a later breaking change.

## Future reserved forms

Qualified headers support future platform/profile scopes without indentation semantics:

```tyx
tools darwin:
watchman

tools linux:
pkg-config
```

MVP parsers may parse these generically but are not required to execute them unless platform support is implemented.

## Diagnostics style

Prefer actionable diagnostics.

Use `Fix` for ambiguity or missing local setup:

```txt
Fix
  Multiple package managers detected:
    pnpm-lock.yaml
    package-lock.json

  Remove the stale lockfile or edit project.tyx.
```

Use `Unsupported` only for unsupported capabilities, and pair it with `Fix` when possible:

```txt
Unsupported
  package manager weirdpm@1.0.0 from package.json#packageManager

Fix
  Use npm, pnpm, yarn, or bun, or edit project.tyx manually.
```
