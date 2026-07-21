---
name: document-feature-technical
description: How to write/update the TECHNICAL documentation for a feature — the engineering view. Use whenever you finish or change a feature implementation and need to record how it works under the hood, or when the docs-sync Stop hook reminds you that source changed but docs didn't. Produces docs/features/<feature>/technical.md covering architecture & data flow, the files that make up the feature, the data model, auth/validation, key decisions, and tests. Pairs with the document-feature-product skill (the user-facing view). Read this BEFORE writing ad-hoc notes — it gives the canonical location and a template so docs stay consistent and discoverable.
user-invocable: true
---

# Document a feature — technical

Record the **engineering view** of a feature: how it actually works, the files
that make it up, and the decisions a future maintainer needs. This is the
companion to [[document-feature-product]] (the user-facing view).

## Where it goes

```
docs/features/<feature>/technical.md     ← this skill
docs/features/<feature>/product.md       ← document-feature-product skill
docs/features/README.md                  ← index (product skill owns it)
```

- `<feature>` is a kebab-case slug. Match it to how the codebase already names
  the feature (its module/package/directory) so the docs are easy to trace back.
- If this project pins the docs directory elsewhere (via
  `.claude/feature-docs.json` `docsPath`, or the plugin's `FEATURE_DOCS_DOCS_PATH`
  env var), use that path instead of `docs/features/`.
- One file per feature — **update the existing `technical.md` in place**, don't
  spawn `technical-v2.md`. Keep it current with the code, not a changelog.

## How to write it

1. **Read the code first.** Describe what the code actually does today, never
   aspirational or planned behavior. If the project has architectural
   conventions (a data-access layer, a service pattern, a module boundary),
   describe the feature in those terms.
2. Fill the template below. Drop sections that genuinely don't apply — say so in
   one line rather than leaving an empty stub.
3. **Link real files** as clickable references (`path/to/file:line`), and
   cross-link the matching `product.md`.
4. When you change a feature, update the affected sections (data model, files,
   decisions) — stale technical docs are worse than none.

## Template

```markdown
# <Feature> — technical

> Product view: ./product.md

## Summary
One or two lines: what this feature does at the system level.

## Status
scaffolded | in progress | shipped — and a line on what's real vs stubbed.

## Architecture & data flow
How it fits the app's architecture. Trace one representative action end to end
(what the user/client triggers → each layer it passes through → where it lands).
Note where reads come from vs where writes go.

## Files & responsibilities
| File | Role |
|------|------|
| `path/to/entry` | request entry / route / handler |
| `path/to/logic` | core logic / use-case / service |
| `path/to/data`  | data access / persistence |
| `path/to/ui`    | UI / presentation |

## Data model
Tables/collections/columns or types touched, and the migration(s) or schema
changes that introduced them. Note any fields with special handling.

## Auth, validation & authorization
Where the request is authenticated, where input is validated, and how access is
authorized. Note the trust boundary (what the client is/ isn't allowed to send).

## External dependencies & integrations
Third-party services, APIs, queues, env vars, or feature flags this relies on.

## Key decisions & trade-offs
Why it's built this way; alternatives rejected; known limitations / TODOs.

## Testing
What's covered (unit / integration / e2e), where those tests live, and how to
run them.

## Extending / gotchas
What a future change most likely touches, and traps to avoid.
```

## Done when

- [ ] `docs/features/<feature>/technical.md` exists/updated and reflects the code.
- [ ] File references are real and clickable; the link to `product.md` resolves.
- [ ] You ran [[document-feature-product]] for the same feature (or confirmed its
      `product.md` is already current) and the `docs/features/README.md` index lists it.
