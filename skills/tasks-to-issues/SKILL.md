---
name: tasks-to-issues
description: "Export the current feature's tasks.md into dependency-ordered GitHub issues for distributed/human tracking. Defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-taskstoissues) if installed."
argument-hint: "Optional: label or milestone notes"
user-invocable: true
---

# tasks-to-issues

Convert the current feature's `tasks.md` into one GitHub issue per task, in the repository's origin remote.

> **This is an *alternative* tracking path, not part of the automated build loop.** `/feature` and `/improve` execute tasks in-session via the Superpowers worktree + subagent-driven TDD loop — they do **not** call this skill. Use `/tasks-to-issues` when a **human or distributed team** will pick up the tasks instead, or alongside the loop purely for visibility. Running it does not implement anything.

Defers to the project's **spec layer** (`.sdd/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → `EXECUTE_SKILL: speckit-taskstoissues $ARGUMENTS`. It reads `tasks.md`, confirms the git remote is a GitHub URL, and creates an issue per task **only** in the repo matching that remote.
- **Plain-markdown specs** → read the feature's `tasks.md` and create one GitHub issue per task via the GitHub MCP server, preserving phase/dependency order in the issue body. **Only** target the repository of `git config --get remote.origin.url` — never another repo.
- **No spec layer** → there's no `tasks.md` to export; suggest `/feature` first.

**Guardrails:** confirm the origin remote is GitHub before creating anything; never create issues in a repository that doesn't match the origin remote; this is an outward-facing action, so confirm with the user before bulk-creating issues.
