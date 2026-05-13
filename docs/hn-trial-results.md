# HN Trial Results

Date: 2026-05-13

Goal: trial canonical Zig Tyx `init`, `up`, and `down` against 10 additional GitHub codebases cloned under `~/repos`.

Safety: repos were cloned to `~/repos`, then copied to disposable `/tmp/tyx-hn-trials/<repo>` directories before running Tyx. Source clones were not mutated. The trial used the repo fixture PATH so package-manager and Docker commands were deterministic stubs rather than real installs/service starts.

Command summary:

```sh
./scripts/verify
mkdir -p ~/repos
# cloned selected repos with git clone --depth 1
# copied each repo to /tmp/tyx-hn-trials/<name>
./bin/tyx init <copy>
./bin/tyx up <copy>
./bin/tyx down <copy>
```

## Results

| Repo | Package manager | init | up | down | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| vercel/next.js | pnpm@10.33.0 | 0 | 0 | 0 | inferred node 20 from repo hints; many scripts |
| supabase/supabase | pnpm@10.24.0 | 0 | 0 | 0 | inferred node 22; many scripts |
| prisma/prisma | pnpm@10.15.1 | 0 | 0 | 0 | inferred node 22 |
| trpc/trpc | pnpm@10.33.1 | 0 | 0 | 0 | inferred node 22 |
| expo/expo | inferred pnpm latest | 0 | 0 | 0 | no root packageManager; inferred pnpm from lockfile |
| withastro/astro | pnpm@10.30.3 | 0 | 0 | 0 | inferred node 22 |
| vitejs/vite | pnpm@10.33.4 | 0 | 0 | 0 | inferred node 22 |
| tailwindlabs/tailwindcss | pnpm@9.6.0 | 0 | 0 | 0 | inferred node 22 |
| TanStack/query | pnpm@10.24.0 | 0 | 0 | 0 | inferred node 22 |
| colinhacks/zod | pnpm@10.12.1 | 0 | 0 | 0 | inferred node 22 |

Evidence command ended with:

```text
real-repos-parity-ok
```

## Observations

- The canonical Zig implementation handled all 10 cloned repos for the MVP flow.
- All 10 repos are large real-world Node/TypeScript projects; this is good HN demo evidence for the `init` inference path.
- The selected repos skew heavily toward pnpm. Before claiming broad package-manager coverage, add npm/yarn/bun-heavy repos or examples.
- No selected repo exercised Compose detection at root. Existing fixture coverage and earlier synthetic real-repo smoke cover compose behavior, but a GitHub repo with root compose files would strengthen release evidence.

## Follow-ups before/after HN

- Add at least one npm and one yarn real repo to the public validation set if time allows.
- Add a root-compose real repo if easy to find.
- Consider limiting rendered scripts in `project.tyx` for very large monorepos, or leave as explicit comprehensive behavior for the MVP.
