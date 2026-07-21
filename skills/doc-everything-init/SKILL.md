---
name: doc-everything-init
description: Set up the doc-everything plugin for the current project — detect the source layout, scaffold the docs/features/ directory with an index, and (only if the defaults don't fit) write a .claude/doc-everything.json config so the docs-sync Stop hook watches the right paths. Use once per repo when adopting the plugin, or when the docs-sync hook is firing on the wrong files or not firing at all.
user-invocable: true
---

# Initialize doc-everything for this project

One-time setup so the docs-sync Stop hook and the `document-feature-*` skills
work in this repo. The hook works out of the box with sensible defaults — you
only need a config file if the defaults don't match this project's layout.

## Steps

1. **Inspect the repo layout.** Find where source lives and what extensions are
   used (e.g. `src/`, `app/`, `lib/`, `packages/*`, or a language-specific root),
   and where documentation should live.

2. **Decide if the defaults fit.** The hook's built-in defaults watch common
   source roots (`src|app|lib|pkg|internal|cmd|packages`) across many languages,
   exclude tests/vendored/generated code, and expect docs under `docs/features/`.
   If that already matches this repo, **skip the config file** — less to maintain.

3. **Only if needed, write `.claude/doc-everything.json`** at the repo root with
   the keys that differ from the defaults:

   ```json
   {
     "docsPath": "docs/features/",
     "srcGlob": "(src|app)/[^[:space:]]+\\.(ts|tsx)",
     "srcExclude": "(\\.(test|spec)\\.|/__tests__/|/node_modules/)",
     "reason": "Source changed but nothing under {DOCS_PATH} did — document the feature."
   }
   ```

   - `srcGlob` / `srcExclude` are **extended regexes** matched against
     `git status --porcelain` lines. Escape backslashes for JSON (`\\.`).
   - `docsPath` must end with a trailing slash.
   - `reason` is optional; `{DOCS_PATH}` in it is substituted at runtime.
   - Any omitted key falls back to the built-in default.
   - Alternatively, these map to env vars `DOC_EVERYTHING_SRC_GLOB`,
     `DOC_EVERYTHING_SRC_EXCLUDE`, `DOC_EVERYTHING_DOCS_PATH`, `DOC_EVERYTHING_REASON`.

4. **Scaffold the docs directory and index.** Create the docs path if missing and
   seed `docs/features/README.md`:

   ```markdown
   # Features

   Per-feature documentation. Each feature has a `product.md` (user-facing view)
   and a `technical.md` (engineering view).

   | Feature | What it is | Docs |
   |---------|------------|------|
   ```

5. **Confirm the hook is active.** The plugin registers a `Stop` hook; after any
   session that changes source without touching the docs path, it blocks once
   with a reminder pointing at the `document-feature-*` skills.

## Done when

- [ ] Source and docs paths are correct (defaults confirmed, or a config file
      written for the ones that differ).
- [ ] `docs/features/README.md` (or the configured docs path) exists with the
      index table.
- [ ] The `document-feature-technical` and `document-feature-product` skills are
      ready to fill in per feature.
