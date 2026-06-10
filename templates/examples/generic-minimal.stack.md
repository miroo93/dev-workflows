# SDD Stack Profile — Minimal — EXAMPLE

> The smallest useful profile: a stack line, verify commands, no specs, no e2e gate.
> Good starting point for a small project or a quick trial. Copy to `docs/stack.md`.

## Stack

- **Runtime / framework:** <your framework>
- **Language:** <your language>
- **Data / backend:** <your data layer, or "none">
- **Styling:** <your styling, or "none">
- **State / data-fetching:** <your approach, or "none">

## Binding context files

- `CLAUDE.md`

## Conventions (the things reviewers must enforce)

- <your one or two hard rules — or delete this line if you have none yet>

## Frozen patterns (change only with explicit user authorization)

none

## Verify commands

```bash
<your lint command>
<your build/typecheck command>
<your test command, if any>
```

## Health / operations

> All optional. With everything `none`, `projecthealth` reports just the always-on
> signals (git working tree + the verify commands above) and marks the rest `n/a`.

- **CI:** none
- **Deploy platform:** none
- **Database / migrations:** none
- **Environments:** single
- **Prod promotion / drift:** none — single repo, deploy from main

## Spec / planning layer

- **Spec location glob:** none
- **Spec tooling:** none
- **Branch naming:** `feature/<slug>`, `improve/<slug>`, `fix/<slug>`

## Backend log / runtime troubleshooting tool

- **Backend-log tool:** none — inspect logs manually

## E2E smoke gate

```yaml
enabled: false
```

## Prerequisite plugins

- `superpowers` (required)
