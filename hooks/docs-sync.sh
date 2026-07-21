#!/usr/bin/env bash

# Stop hook: keep per-feature docs in sync with code changes.
#
# If source under SRC_GLOB has uncommitted working-tree changes but nothing
# under DOCS_PATH does, nudge ONCE to document the feature, pointing at the
# document-feature-* skills (Claude Code) / rules (Cursor). The nudge never
# repeats within a turn.
#
# Runs in two editors, auto-detected from the stop payload on stdin:
#   • Claude Code — guard on `stop_hook_active`; emit {"decision":"block", ...}.
#   • Cursor (>=1.7) — guard on `loop_count` (+ only when status=="completed");
#     emit {"followup_message": ...} to re-prompt the agent.
#
# NB: this inspects the whole working tree (git status), not only what changed
# in the current session — a branch with pre-existing pending source changes
# will trigger the nudge on the first stop.
#
# Language/framework-agnostic. Every path pattern below can be overridden per
# project, in priority order:
#   1. A config file at <repo>/.cursor/doc-everything.json or
#      <repo>/.claude/doc-everything.json (keys: srcGlob, srcExclude, docsPath,
#      reason). Missing keys fall back to defaults.
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

# What the agent sees when code changed but docs didn't. {DOCS_PATH} is
# substituted. Editor-neutral wording — document-feature-* is a skill in Claude
# Code and a rule in Cursor, but the name is the same in both.
# Written as one printf so the message has no stray line-continuation backslashes.
DEF_REASON="$(printf '%s ' \
  'Source changed but nothing under {DOCS_PATH} did.' \
  'Document the feature you implemented/changed in THIS task: update' \
  '{DOCS_PATH}<feature>/technical.md (see document-feature-technical),' \
  '{DOCS_PATH}<feature>/product.md (see document-feature-product), and' \
  'the {DOCS_PATH}README.md index. If this change genuinely needs no docs (pure' \
  'refactor, tests, formatting, config/dep bump, scaffolding only), say why in one' \
  'line and stop again.')"

# ────────────────────────────────────────────────────────────────────────────

# Hard dependency: without jq we can neither parse the hook payload nor emit a
# block decision. Fail open (let the stop proceed) rather than silently misbehave.
command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

# Detect the calling editor from the stop-payload shape: Cursor's `stop` hook
# sends {"status","loop_count"}; Claude Code's sends {"stop_hook_active",...}.
if [ "$(printf '%s' "$input" | jq -r 'has("loop_count")' 2>/dev/null)" = "true" ]; then
  MODE="cursor"
else
  MODE="claude"
fi

# Nudge at most once per turn; never re-trigger.
if [ "$MODE" = "cursor" ]; then
  # Only act on a normally-completed turn — not on an abort or error.
  [ "$(printf '%s' "$input" | jq -r '.status // "completed"')" = "completed" ] || exit 0
  # loop_count > 0 → we already submitted a follow-up this turn.
  [ "$(printf '%s' "$input" | jq -r '(.loop_count // 0) > 0' 2>/dev/null)" = "true" ] && exit 0
else
  # stop_hook_active → we already blocked once this stop-sequence.
  [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0
fi

# Locate the repo; bail quietly if we're not in a git checkout.
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0

# Load optional per-project config: first existing file wins. Prefer the current
# editor's directory, then fall back to the other.
cfg=""
if [ "$MODE" = "cursor" ]; then
  for c in "$root/.cursor/doc-everything.json" "$root/.claude/doc-everything.json"; do
    [ -f "$c" ] && { cfg="$c"; break; }
  done
else
  for c in "$root/.claude/doc-everything.json" "$root/.cursor/doc-everything.json"; do
    [ -f "$c" ] && { cfg="$c"; break; }
  done
fi
cfg_get() {
  # $1 = json key; echoes value or empty if no config file / key absent.
  [ -n "$cfg" ] || return 0
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
  if [ "$MODE" = "cursor" ]; then
    # Cursor: auto-submit a follow-up user message to keep the agent iterating.
    jq -n --arg m "$REASON" '{followup_message: $m}'
  else
    # Claude Code: block this stop once and feed the reason back to Claude.
    jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
  fi
  exit 0
fi

exit 0
