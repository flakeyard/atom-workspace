# Architecture Decision Records

These records hold the decisions about the design of atom-workspace itself,
including its public API, with ids `ADR-NNNN`. Decisions that bind more than one
repository of flakeyard or the organization itself are `FY-NNNN` records in
[flakeyard/decisions][decisions]. A record here MUST NOT contradict an accepted
`FY` record.

All ADRs live in `records/` as `NNNN-slug.md`. **Files never move.** Numbers are
global and never reused. Status is stored in frontmatter; `INDEX.md` groups
records by status.

```text
docs/adr/
├── README.md      this file
├── INDEX.md       generated, do not edit by hand
├── template.md    copy into records/ to start a new ADR
└── records/       all ADRs, any status
```

## Statuses

- **proposed**: under discussion.
- **accepted**: in effect; its Constraints are binding.
- **rejected**: considered and declined; kept so the question is not reopened
  blindly.
- **superseded**: replaced; `superseded_by` points to the replacement.
- **deprecated**: no longer relevant, nothing replaces it.

## Title

The title lives in the `title` frontmatter field only; records start with
`## Context`, without a top-level heading.

## Changing status

1. Edit `status` (and `supersedes` / `superseded_by` on both records).
2. Regenerate `INDEX.md`.

## Linking

Inside `records/`, ADRs link to each other with sibling paths, e.g.
`[ADR-0004](0004-short-title.md)`. They stay valid because files do not move.
Records of flakeyard/decisions are cited by their full id with a link to the
record on GitHub, as reference-style links:

```markdown
[FY-0016][fy-0016] requires ...

[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
```

## Governed code

`affects` lists the code a decision governs, as path globs (`src/auth/**`). A
decision that governs other repositories uses `repository-glob:path-glob`
(`atom-*:flake.nix`).

[decisions]: https://github.com/flakeyard/decisions
