---
name: implement
description: "Execute the tasks in tasks.md for the current feature. Defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-implement) if installed. Note: /feature and /improve run their own TDD implement loop — use this only for standalone task execution."
argument-hint: "Optional: task number or range to execute (e.g. 1, 1-3)"
user-invocable: true
---

# implement

Execute the task checklist for the current feature.

> **Note:** `/feature` and `/improve` run their own Superpowers subagent-driven TDD loop and do **not** call this skill. Use `/implement` only when you want to run a pre-existing `tasks.md` standalone (outside those pipelines).

Defers to the project's **spec layer** (`.sdd/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → `EXECUTE_SKILL: speckit-implement $ARGUMENTS`
- **Plain-markdown specs** → execute the tasks in `tasks.md` in order with TDD discipline (red → green → refactor per task), running the profile's verify commands and committing after each task. Prefer `superpowers:subagent-driven-development` for a fresh-context-per-task loop.
- **No spec layer** → there's no `tasks.md` to run; suggest `/feature` instead.
