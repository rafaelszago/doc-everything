#!/usr/bin/env bash

# Stop hook: keep per-feature docs in sync with code changes.
#
# If source under SRC_GLOB has uncommitted working-tree changes but nothing
# under DOCS_PATH does, block the stop ONCE with a reminder pointing at the
# document-feature-* skills. The stop_hook_active guard prevents an infinite
# block loop — after the first block, the next stop is allowed.
#
# NB: this inspects the whole working tree (git status), not only what changed
# in the current session — a branch with pre-existing pending source changes
# will trigger the nudge on the first stop.
#
# Language/framework-agnostic. Every path pattern below can be overridden per
# project, in priority order:
#   1. A config file at <repo>/.claude/doc-everything.json (keys: srcGlob,
#      srcExclude, docsPath, reason). Missing keys fall back to defaults.
#   2. Environment variables: DOC_EVERYTHING_SRC_GLOB, DOC_EVERYTHING_SRC_EXCLUDE,
#      DOC_EVERYTHING_DOCS_PATH, DOC_EVERYTHING_REASON.
#   3. The built-in defaults below.
#
# Requires: git, jq.

set -uo pipefail

# ── DEFAULTS ────────────────────────────────────────────────────────────────

# Source files we care about (matched against `git status` porcelain lines).
# Covers the common source roots and languages; override per project.
#   - (^|[ /]) anchors the source root to a path boundary, so `mysrc/` and
#     `my-app/` don't match `src/` / `app/`.
#   - ($|[^[:alnum:]]) anchors the extension, so the single-letter alternatives
#     (m, c, h) don't match prefixes like .md, .csv, .css, .heic.
DEF_SRC_GLOB='(^|[ /])(src|app|lib|pkg|internal|cmd|packages)/[^[:space:]]+\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|kts|swift|m|mm|c|cc|cpp|cxx|h|hpp|cs|php|scala|ex|exs|clj|vue|svelte)($|[^[:alnum:]])'

# Exclude tests, snapshots, generated output, and vendored/third-party code —
# changes to these are not feature implementations.
DEF_SRC_EXCLUDE='(\.(test|spec)\.|_test\.|_spec\.|\.stories\.|/__tests__/|/__mocks__/|/tests?/|/e2e/|/vendor/|/node_modules/|/dist/|/build/|/\.next/|/generated/|\.gen\.|\.pb\.)'

# Feature documentation directory (trailing slash).
DEF_DOCS_PATH='docs/features/'

# What Claude sees when code changed but docs didn't. {DOCS_PATH} is substituted.
# Written as one printf so the message has no stray line-continuation backslashes.
DEF_REASON="$(printf '%s ' \
  'Source changed but nothing under {DOCS_PATH} did.' \
  'Document the feature you implemented/changed in THIS task: update' \
  '{DOCS_PATH}<feature>/technical.md (use the document-feature-technical skill),' \
  '{DOCS_PATH}<feature>/product.md (use the document-feature-product skill), and' \
  'the {DOCS_PATH}README.md index. If this change genuinely needs no docs (pure' \
  'refactor, tests, formatting, config/dep bump, scaffolding only), say why in one' \
  'line and stop again.')"

# ────────────────────────────────────────────────────────────────────────────

# Hard dependency: without jq we can neither parse the hook payload nor emit a
# block decision. Fail open (let the stop proceed) rather than silently misbehave.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

# Already blocked once this stop-sequence → let the turn end.
if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

# Locate the repo; bail quietly if we're not in a git checkout.
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0

# Load optional per-project config file.
cfg="$root/.claude/doc-everything.json"
cfg_get() {
  # $1 = json key; echoes value or empty if file/key absent.
  [ -f "$cfg" ] || return 0
  jq -r --arg k "$1" '.[$k] // empty' "$cfg" 2>/dev/null
}

# Resolve each setting: config file → env var → default.
SRC_GLOB="$(cfg_get srcGlob)";       SRC_GLOB="${SRC_GLOB:-${DOC_EVERYTHING_SRC_GLOB:-$DEF_SRC_GLOB}}"
SRC_EXCLUDE="$(cfg_get srcExclude)"; SRC_EXCLUDE="${SRC_EXCLUDE:-${DOC_EVERYTHING_SRC_EXCLUDE:-$DEF_SRC_EXCLUDE}}"
DOCS_PATH="$(cfg_get docsPath)";     DOCS_PATH="${DOCS_PATH:-${DOC_EVERYTHING_DOCS_PATH:-$DEF_DOCS_PATH}}"
REASON="$(cfg_get reason)";          REASON="${REASON:-${DOC_EVERYTHING_REASON:-$DEF_REASON}}"

# Substitute {DOCS_PATH} placeholder in the reason text.
REASON="${REASON//\{DOCS_PATH\}/$DOCS_PATH}"

# -uall expands untracked directories to individual files (plain --porcelain
# collapses a new dir to just "?? src/", hiding the files inside).
changes="$(git status --porcelain -uall 2>/dev/null)" || exit 0
[ -n "$changes" ] || exit 0

# Source changed (excluding tests / vendored / generated)?
code_changed="$(printf '%s\n' "$changes" \
  | grep -E "$SRC_GLOB" \
  | grep -vE "$SRC_EXCLUDE" || true)"

# Anything under the docs dir touched?
docs_changed="$(printf '%s\n' "$changes" | grep -E "$DOCS_PATH" || true)"

if [ -n "$code_changed" ] && [ -z "$docs_changed" ]; then
  jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
  exit 0
fi

exit 0
