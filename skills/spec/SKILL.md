---
name: spec
description: "Create or update a feature spec. Convenience entry point that defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-specify) if installed."
argument-hint: "Describe the feature to specify"
user-invocable: true
---

# spec

Create or amend the spec for a feature, as the first planning artifact before `/feature` or `/improve` build it.

This skill defers to the project's **spec layer** (see `docs/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → invoke `speckit-specify` with the same `$ARGUMENTS`:
  `EXECUTE_SKILL: speckit-specify $ARGUMENTS`
- **Plain-markdown specs** → create/update `spec.md` in the project's spec location (from the profile's spec glob): a short feature spec with overview, user stories, functional requirements, and acceptance criteria. Mark genuine ambiguities as `NEEDS_CLARIFICATION`. Commit it.
- **No spec layer ("none")** → tell the user this project doesn't use specs; suggest running `/feature` (which drives the design via brainstorm + grill) directly.
