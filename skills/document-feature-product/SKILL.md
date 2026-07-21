---
name: document-feature-product
description: How to write/update the PRODUCT documentation for a feature — the user-facing view. Use whenever you finish or change a feature and need to record what it does for the user, or when the docs-sync Stop hook reminds you that source changed but docs didn't. Produces docs/features/<feature>/product.md (what it is + who it's for, why it exists, the user journey, states/edge cases, copy) AND maintains the docs/features/README.md index. Pairs with the document-feature-technical skill (the engineering view). Read this BEFORE writing product notes ad-hoc — it gives the canonical location, template, and index conventions.
user-invocable: true
---

# Document a feature — product

Record the **user-facing view** of a feature: what it does, who it's for, and
how a person moves through it. This is the companion to
[[document-feature-technical]] (the engineering view). Describe the experience
and the value to the user, not the implementation.

## Where it goes

```
docs/features/<feature>/product.md       ← this skill
docs/features/README.md                  ← index — this skill owns it
docs/features/<feature>/technical.md     ← document-feature-technical skill
```

- `<feature>` is a kebab-case slug — the same slug used by the matching
  `technical.md`.
- If this project pins the docs directory elsewhere (via
  `.claude/doc-everything.json` `docsPath`, or the plugin's `DOC_EVERYTHING_DOCS_PATH`
  env var), use that path instead of `docs/features/`.
- One file per feature — **update `product.md` in place** as behavior changes.

## How to write it

1. **Describe what ships**, not the roadmap. If a feature is scaffolded/stubbed,
   say so plainly in the journey.
2. Fill the template. Skip a section in one line if it doesn't apply.
3. **Always update `docs/features/README.md`** — add/refresh the one-line entry
   for this feature so the index stays a complete map of the product.
4. Cross-link the matching `technical.md`.
5. If the product has copy/localization or a visual/design language worth noting
   (tone, terminology, colors that carry meaning), capture it — see the optional
   sections in the template.

## Template

```markdown
# <Feature> — product

> Technical view: ./technical.md

## What it is
One line: the feature in user terms, and who it's for.

## Why it exists
The problem it solves and the value it delivers.

## Where the user finds it
Entry points the user actually reaches (route/screen, nav item, trigger).

## User journey
Numbered steps of what the user sees and does, start to finish. Quote key UI
copy where it matters.

## States & edge cases
Loading, empty, error, success — and any gating (signed-out, incomplete setup,
plan-locked). What the user sees in each.

## Copy & localization
(Optional) Primary language and any translations; where the copy lives. Note if
copy is centralized (content files) vs hardcoded.

## Visual language
(Optional) Design tokens / accent meaning / iconography this feature relies on,
and any conventions it must respect.

## Out of scope / future
What this feature deliberately does not do yet.
```

## The index — `docs/features/README.md`

Keep a single table mapping every documented feature. One row per feature:

```markdown
# Features

| Feature | What it is | Docs |
|---------|------------|------|
| Onboarding | First-run setup that personalizes the experience | [product](./onboarding/product.md) · [technical](./onboarding/technical.md) |
```

When you document a new feature, add its row; when a feature changes name or is
removed, fix the index in the same task.

## Done when

- [ ] `docs/features/<feature>/product.md` exists/updated and matches what ships.
- [ ] `docs/features/README.md` lists the feature with working links.
- [ ] Copy/localization and visual-language notes are accurate (or omitted as N/A).
- [ ] You ran [[document-feature-technical]] for the same feature (or confirmed
      its `technical.md` is current).
