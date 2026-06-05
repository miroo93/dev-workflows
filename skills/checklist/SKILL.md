---
name: checklist
description: "Generate a requirements-quality checklist (\"unit tests for the requirements\") for the current feature on a chosen dimension like security, ux, or api. Defers to your project's spec tooling (e.g. GitHub Spec-Kit's /speckit-checklist) if installed."
argument-hint: "<focus dimension> — e.g. security, ux, api, performance"
user-invocable: true
---

# checklist

Generate a checklist that validates the **requirements themselves** — are they complete, clear, consistent, and measurable — for a chosen risk dimension. This is **"unit tests for the English,"** NOT a test of the implementation.

- ✅ *"Is 'fast load' quantified with a specific threshold? [Clarity]"*
- ✅ *"Are auth requirements defined for every protected resource? [Coverage]"*
- ❌ *"Verify the button click works"* (that tests the build, not the requirement)

> **`/feature` runs this as an optional gate** (§2b) for high-risk T3 features. Use `/checklist` standalone to add a quality dimension to an existing spec.

Defers to the project's **spec layer** (`docs/stack.md` → *Spec / planning layer*):

- **GitHub Spec-Kit installed** → `EXECUTE_SKILL: speckit-checklist $ARGUMENTS`. It writes `FEATURE_DIR/checklists/<domain>.md` (CHK### items). Spec-Kit's `/speckit-clarify` re-validates these items, and `/speckit-analyze` reads them — so generating one makes those gates stricter.
- **Plain-markdown specs** → write a short `checklists/<domain>.md` next to the feature's `spec.md` with 5–15 requirement-quality questions for the chosen dimension, each tagged `[Completeness/Clarity/Consistency/Measurability/Coverage]` and referencing a spec section or marked `[Gap]`. Do not write implementation test cases.
- **No spec layer** → there's no spec to validate; suggest `/feature` instead.

**Scope it.** A checklist is worth the ceremony for genuinely high-risk work (auth, payments, data-shape changes, compliance-sensitive UX). For ordinary features the grill + clarify gates already cover requirement quality — skip it.
