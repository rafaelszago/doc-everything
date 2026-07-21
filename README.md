# doc-everything

Keep per-feature documentation in sync with your code — in any project, any
language. A Stop hook nudges you to document whatever you just changed, and two
skills give you canonical templates for the two views of a feature.

## What's in it

| Piece | Type | What it does |
|-------|------|--------------|
| `docs-sync` | Stop hook | If your working tree has uncommitted source changes but nothing under the docs path, blocks the stop **once** with a reminder to document the feature. The `stop_hook_active` guard prevents a block loop. |
| `document-feature-technical` | skill | Template for the **engineering view** → `docs/features/<feature>/technical.md`. |
| `document-feature-product` | skill | Template for the **user-facing view** → `docs/features/<feature>/product.md`, and maintains the `docs/features/README.md` index. |
| `doc-everything-init` | skill | One-time per-repo setup: scaffolds the docs dir + index and writes a config only if the defaults don't fit. |

## Install

Add the marketplace from GitHub, then install the plugin — via the CLI:

```bash
claude plugin marketplace add rafaelszago/doc-everything
claude plugin install doc-everything
```

…or from an interactive Claude Code session (the `/plugin` menu, or directly):

```
/plugin marketplace add rafaelszago/doc-everything
/plugin install doc-everything
```

By default the plugin installs at **user scope**, so its `docs-sync` Stop hook
is active in *every* project you open. To limit it to one repo, install from
inside that repo with a narrower scope:

```bash
claude plugin install doc-everything --scope project   # shared via the repo's .claude settings
claude plugin install doc-everything --scope local     # only your local checkout
```

Manage it later with `claude plugin update | disable | enable | uninstall
doc-everything`. If another installed plugin shares the name, use the fully
qualified id `doc-everything@doc-everything`.

## Convention

```
docs/features/
├── README.md              ← index of all features
└── <feature>/
    ├── product.md         ← what it does for the user
    └── technical.md       ← how it works under the hood
```

## Configuration

The hook works out of the box: it watches common source roots
(`src|app|lib|pkg|internal|cmd|packages`) across many languages, ignores
tests/vendored/generated code, and expects docs under `docs/features/`.

To tune it, add `.claude/doc-everything.json` at the repo root (any omitted key
falls back to the default):

```json
{
  "docsPath": "docs/features/",
  "srcGlob": "(src|app)/[^[:space:]]+\\.(ts|tsx)",
  "srcExclude": "(\\.(test|spec)\\.|/__tests__/|/node_modules/)",
  "reason": "Source changed but nothing under {DOCS_PATH} did — document the feature."
}
```

- `srcGlob` / `srcExclude` are extended regexes matched against
  `git status --porcelain` lines (escape backslashes for JSON).
- `docsPath` ends with a trailing slash. `{DOCS_PATH}` in `reason` is substituted.
- Or set the env vars `DOC_EVERYTHING_SRC_GLOB`, `DOC_EVERYTHING_SRC_EXCLUDE`,
  `DOC_EVERYTHING_DOCS_PATH`, `DOC_EVERYTHING_REASON`.

Run the `doc-everything-init` skill once to set this up interactively.

## Requirements

`git` and `jq` (used by the hook).

## Notes

- The hook only fires inside a git checkout and looks at your uncommitted
  working-tree changes (staged, unstaged, or untracked) — not only what changed
  this session. If you resume a branch that already has pending source changes,
  it will nudge you on the first stop even though you haven't touched that code
  yet.
- It never blocks more than once per stop sequence — if a change genuinely needs
  no docs (refactor, tests, config bump), say why in one line and stop again.
