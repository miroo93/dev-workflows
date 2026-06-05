---
name: plan
description: "Generate a plan.md for the current feature from its spec.md. Defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-plan) if installed."
argument-hint: "Optional: additional planning notes"
user-invocable: true
---

# plan

Generate the implementation plan for the current feature from its spec.

Defers to the project's **spec layer** (`docs/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → `EXECUTE_SKILL: speckit-plan $ARGUMENTS`
- **Plain-markdown specs** → create/update `plan.md` next to the feature's `spec.md`: tech-stack decisions, component/file structure, data flow, and a TDD task ordering (test tasks before implementation tasks). Commit it.
- **No spec layer** → suggest running `/feature`, which handles planning inline.
