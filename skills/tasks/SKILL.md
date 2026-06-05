---
name: tasks
description: "Generate a tasks.md from plan.md for the current feature. Defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-tasks) if installed."
argument-hint: "Optional: additional task notes"
user-invocable: true
---

# tasks

Generate the dependency-ordered task checklist for the current feature from its plan.

Defers to the project's **spec layer** (`docs/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → `EXECUTE_SKILL: speckit-tasks $ARGUMENTS`
- **Plain-markdown specs** → create/update `tasks.md` next to the feature's `plan.md`. TDD ordering is required: each implementation task preceded by its test task. Format: `- [ ] TXXX [P] [USN] Description with file path`. Phase order: Setup → Foundational → User Story phases (tests before impl) → Polish. Commit it.
- **No spec layer** → suggest running `/feature`, which generates tasks inline.
