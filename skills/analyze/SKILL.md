---
name: analyze
description: "Run a read-only cross-artifact consistency check across spec.md, plan.md, and tasks.md for the current feature, before implementation. Defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-analyze) if installed."
argument-hint: "Optional: analysis focus"
user-invocable: true
---

# analyze

Cross-check that the current feature's `spec.md`, `plan.md`, and `tasks.md` actually agree **before** any code is written: requirements with no covering task, tasks with no source requirement, terminology drift, contradictions, and over-build. This is the cheapest place to catch artifact drift — one read-only pass instead of wasted implementation.

> **`/feature` and `/improve` run this as a built-in gate** (`/feature` §4b, `/improve` §3b for T3). Use `/analyze` standalone when you want the check on an existing spec/plan/tasks set outside those pipelines.

**READ-ONLY** — this never edits files. It produces a findings report; you act on it.

Defers to the project's **spec layer** (`docs/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → `EXECUTE_SKILL: speckit-analyze $ARGUMENTS`. It loads spec/plan/tasks (and `/memory/constitution.md` if present), builds a requirements↔tasks coverage map, and emits a severity-ranked findings table (CRITICAL/HIGH/MEDIUM/LOW) plus coverage %.
- **Plain-markdown specs** → read the feature's `spec.md`, `plan.md`, `tasks.md` (and any `checklists/`) and report, without editing: (1) coverage gaps — requirements with no task, tasks with no requirement; (2) inconsistency — terminology drift, entities in plan absent from spec; (3) ambiguity — vague unmeasurable requirements, unresolved TODO markers; (4) over-build — plan/tasks beyond what the spec asked. Rank CRITICAL/HIGH/MEDIUM/LOW.
- **No spec layer** → there are no artifacts to cross-check; suggest `/feature` (which produces them) instead.

**Acting on findings:** CRITICAL/HIGH (coverage gap, contradiction) → fix the offending artifact before implementing. MEDIUM/LOW → may proceed; flag for reviewers. Constitution/frozen-pattern violations are always CRITICAL.
