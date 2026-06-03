---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

## How to ask

Ask questions using the **AskUserQuestion** tool — never as inline text I have to type a reply to. Each question must offer concrete, selectable options.

- Ask **one decision at a time** (one AskUserQuestion call with a single question), so each answer can inform the next branch. Only batch multiple questions into one call when they are genuinely independent.
- For every question, **make your recommended answer the first option** and append "(Recommended)" to its label.
- Give each option a `description` that explains the trade-off or what choosing it implies.
- The tool always provides an "Other" escape hatch, so I can override with custom text when none of the options fit — you don't need to add one.

## Before asking

If a question can be answered by exploring the codebase, explore the codebase instead of asking. Only surface decisions to me that genuinely require my judgment.
