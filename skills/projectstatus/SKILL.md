---
name: projectstatus
description: Use when the user asks "what's the project status", "where are we", "what should I work on next", "what's left", "what's blocked", or wants a spec-progress snapshot and a ranked next-action recommendation. Reads the project's spec layer (tasks lists, milestone order, blockers) from the stack profile. Progress only — for CI/DB/deploy health use /projecthealth.
argument-hint: "Optional: a milestone/spec name to focus the report on"
user-invocable: true
---

# projectstatus — spec progress & what to work next

**Invoke as `/projectstatus`.**

## Overview

Reports how far the project's **spec-driven work** has progressed and recommends
**one** thing to work next. It reads the spec layer declared in the project's
**stack profile**, reports progress per milestone/feature, surfaces blockers, and
offers to start the top recommendation via the matching hand-off skill.

**Core principle:** the task checkboxes ARE the source of truth for progress.
Don't guess from git or memory; parse the boxes. **Blockers first, then milestone
order.**

**Scope:** spec/feature progress only. It does **not** check CI, the database,
deploys, or environment drift — that's the separate `/projecthealth` skill.
Read-only: never edit specs or tick boxes here.

## Load the stack profile first

Read the project's **stack profile**: `docs/stack.md` (preferred) or `sdd-stack.md`
at the repo root. From its **Spec / planning layer** section take:

- **Spec location glob** — where feature specs/tasks live (e.g. `specs/**/tasks.md`,
  `docs/features/*.md`). If this is **`none`**, the project has no spec oracle: say so
  and fall back to summarizing open PRs / TODOs / the issue tracker, then stop.
- **Spec tooling** — e.g. GitHub Spec-Kit (`.specify/`), plain markdown, or none.
  When Spec-Kit is present, the hand-offs below defer to it via the dev-workflows
  thin entry points (`/spec`, `/tasks`, `/implement`, `/analyze`).
- **Branch naming** — for context when recommending where work lands.

Also read the **Binding context files** (e.g. `CLAUDE.md`, a constitution/principles
file). A constitution — if the project has one — encodes the **gates** (e.g.
test-first, migrations-first) that constrain task order; honor them when ranking.

Everywhere this skill says **[SPEC GLOB]**, substitute the profile's spec location;
everywhere it says **[PROJECT CONTEXT]**, substitute a compact summary of the binding
context + conventions.

## When to Use

- "What's the project status / where are we / what's left / what's next?"
- "What's blocked?" / "What should I pick up?"
- Before starting a work session, to orient.

**When NOT to use:** checking deploy/CI/DB health (→ `/projecthealth`); actually
*doing* the work (→ the hand-off skills below); writing or re-scoping a spec
(→ `/spec`, `/tasks`).

## What to read

| Artifact | Where | Tells you |
|---|---|---|
| Milestones / features | the **[SPEC GLOB]** dirs, ordered (by numeric prefix if present) | the sequence of work |
| Task list | each spec's `tasks.md` (or equivalent) | `- [ ]`/`- [x]` progress, `## Phase N` grouping, `TXXX` items |
| Decisions | a `DECISIONS.md` / decision log if the project keeps one | resolved clarifications + open external dependencies |
| Gates | the constitution/principles file from the profile, if any | principles (test-first, additive-migrations, …) that gate task order |
| Spec / plan | each spec's `spec.md` / `plan.md` | context when a feature has **no** task list yet |

**Task line format (Spec-Kit style, adapt to the project's):** `- [ ] TXXX [P?] [USN]
Description (path)` — `[P]`=parallelizable, `[S]`=setup, `[F]`=foundational,
`[USN]`=user story, `[L]`=launch, `[POL]`=polish. Projects using plain-markdown
checklists just have `- [ ] description` — count those the same way.

## Procedure

1. **Scan progress.** For each spec under **[SPEC GLOB]** with a task list, count
   done/todo boxes and find the **current phase** (first `## Phase` containing an
   unchecked task) and the **next 1–3 unchecked tasks** in it. Note any spec with
   **no task list** (not yet broken down).
2. **Detect blockers.** Scan unchecked task lines and the decision log for blocker
   signals (see table). Classify each as **external** (needs a human — owner access,
   third-party input, a clarification) vs **internal** (a `gated on TXXX` / `applied
   only after …` dependency you can satisfy by doing the prerequisite task).
3. **Rank (blockers first, then milestone order):**
   - Externally-blocked items → list as **⛔ Blocked (flag, don't recommend)**.
   - Otherwise the **earliest** spec (lowest numeric prefix / declared order) with
     *actionable* unchecked tasks is the current focus. Within it, respect phase order
     and any **test-first gate** from the constitution (a `TEST … fail first` task
     precedes its implementation task — recommend the test task, not the impl).
   - Specs with **no task list** → next action is to generate one (`/tasks`).
4. **Report** (format below).
5. **Offer to start** the top recommendation via the matching hand-off skill.

### Blocker signals to grep for

`⛔`, `BLOCKED`, `block and flag`, `NEEDS CLARIFICATION`, `gated on`, `applied
only after`, `pending owner`, `open dependency`, `⚠️`.

### Mechanical scan (adapt the glob to the profile)

```bash
# Use POSIX [[:space:]], NOT \s — awk does not understand \s.
cd "$(git rev-parse --show-toplevel)"
# SPEC_GLOB_DIR comes from the stack profile's "Spec location glob" (dir part).
for d in specs/[0-9]*/; do                      # adapt: e.g. docs/features/*/
  t="$d/tasks.md"                               # adapt: the profile's task filename
  if [ ! -f "$t" ]; then echo "$d  — NO task list (needs /tasks)"; continue; fi
  done=$(grep -cE '^[[:space:]]*-[[:space:]]*\[[xX]\]' "$t")
  todo=$(grep -cE '^[[:space:]]*-[[:space:]]*\[ \]' "$t")
  total=$((done+todo)); pct=$(( total ? 100*done/total : 0 ))
  # current phase = first "## Phase" heading that has an unchecked box below it
  phase=$(awk '/^## Phase/{p=$0} /^[[:space:]]*-[[:space:]]*\[ \]/{print p; exit}' "$t")
  printf "%-34s %2d/%-3d (%3d%%)  %s\n" "$d" "$done" "$total" "$pct" "${phase:-ALL DONE}"
done
# Blocked items across all specs:
grep -rnE '^[[:space:]]*-[[:space:]]*\[ \].*(⛔|BLOCKED|block and flag|NEEDS CLARIFICATION|gated on|applied only after|pending owner|open dependency|⚠️)' specs/[0-9]*/tasks.md
```

## Output format

```
## 📊 Project status — spec progress

| Milestone / feature | Progress | Status |
|---|---|---|
| 000 scaffold | 33/36 (92%) | 3 ⛔ blocked (owner access) |
| 001 auth | 32/54 (59%) | ▶ in progress — Phase 5 |
| 002 game-loop | 0/70 | not started |
| …                   |          |        |

### ▶ Current focus: <milestone/feature> — Phase <n> <title>
Next actionable tasks:
- TXXX <desc> (<path>)
- TXXX <desc> (<path>)

### ⛔ Blocked (need a human)
- <milestone> TXXX — <one-line why + who unblocks>

### ✅ Recommended next: <TXXX / "generate tasks for NNN">
<one or two sentences: why this one — milestone order + gates>
```

Then ask whether to start it, naming the exact hand-off skill.

## Hand-off (after the report, offer ONE)

| Situation | Offer |
|---|---|
| Feature has actionable tasks | `/implement` to execute the next tasks (defers to the project's spec tooling) |
| Spec has no task list | `/tasks` (run `/plan` first if there's no plan) |
| Top item is a `NEEDS CLARIFICATION` blocker | `/spec` (Spec-Kit: `/speckit-clarify`) to resolve it in the spec |
| Artifacts look inconsistent before building | `/analyze` |

## Common Mistakes

- **Guessing progress from git/memory** instead of counting task boxes. The boxes are
  truth.
- **Recommending an externally-blocked task** (⛔ owner/third-party). Flag it, then
  recommend the next *actionable* item.
- **Recommending an implementation task whose failing-test task is still unchecked** —
  if the project's constitution is test-first, the test task comes first.
- **Skipping the milestone-order rule** and picking a later milestone's task while an
  earlier one still has actionable work.
- **Recommending more than one thing.** Pick the single best next action; list the rest
  as context.
- **Scope creep into CI/DB/deploy health.** That's `/projecthealth`, not this.
- **Hardcoding `specs/NNN/tasks.md`** when the profile points somewhere else. Read the
  **Spec location glob** from the stack profile.
- **Editing specs or ticking boxes.** This skill is read-only.
