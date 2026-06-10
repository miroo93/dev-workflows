---
name: projecthealth
description: Use when the user asks "is the project healthy", "is CI green", "what's red", "are we deployable", "any failing checks", "is anything broken", "advisor/migration/deploy status", or wants an operational health snapshot. Covers git/PRs/CI, local quality gates, and — when the stack profile declares them — database migrations+advisors, deploys, and prod drift. For spec progress / "what to work next" use /projectstatus.
argument-hint: "Optional: an area to focus on (ci | db | deploy | drift)"
user-invocable: true
---

# projecthealth — operational health snapshot

**Invoke as `/projecthealth`.**

## Overview

The operational counterpart to `/projectstatus`. Where `/projectstatus` reports
spec *progress*, this reports whether the running system is **green and
deployable**: working tree, open PRs + CI, local quality gates, and — for projects
whose stack profile declares them — database migrations/advisors, deploys, and how
far a promoted environment has drifted.

**Core principle:** report **red first**. Aggregate every signal, surface what's
broken or drifting at the top, give an honest GREEN / YELLOW / RED verdict, then
offer the matching remediation. **Read-only** — diagnose and recommend; don't push
fixes, apply migrations, or deploy from this skill.

**Scope:** system health, not feature progress. For "where are we / what to work
next" use `/projectstatus`.

## Load the stack profile first

Read the project's **stack profile**: `docs/stack.md` (preferred) or `sdd-stack.md`
at the repo root. The profile decides which signals exist for this project — **omit a
field and projecthealth skips that signal** (report it as "n/a", never as red). Take:

- **Verify commands** — the lint / typecheck / test commands. Everywhere this skill
  says **[VERIFY]**, run these in the profile's order.
- **Health / operations** section (optional):
  - **CI** — how to read CI (e.g. `gh run list` / `gh run view` on named workflows),
    or `none`.
  - **Deploy platform** — e.g. Vercel (`vercel ls` / `/vercel:status`), Netlify, Fly,
    or `none`.
  - **Database / migrations** — e.g. Supabase migrations dir + advisors, Prisma
    migrate, or `none`.
  - **Environments** — one or many (e.g. `staging` + `prod`, each with a ref/url). When
    more than one, run the DB/deploy checks **per environment** and never mix them.
  - **Prod promotion / drift** — how dev is promoted to prod (separate repo + sync log,
    or "single repo, deploy from main"), or `none`.

If the profile has **no Health / operations** section, run the always-on signals
(working tree, PRs+CI if a CI command exists, [VERIFY]) and report the stack-specific
signals as **n/a (not configured)**.

## Health signals (what to check)

| Area | Source | Red = | Gated on |
|---|---|---|---|
| Working tree | `git status` / `git log @{u}..HEAD` | uncommitted or unpushed work where it matters | always |
| Open PRs | `gh pr list` | PRs blocked, conflicting, or stale | always |
| CI | `gh run list` / `gh run view` on the profile's workflows | any failing required check | profile **CI** ≠ none |
| Quality gates | **[VERIFY]** | lint/type/test failures | always |
| Migrations | profile's migrations dir vs the DB's applied list (per env) | files not yet applied (pending) | profile **Database** ≠ none |
| Advisors | the DB's advisor/lint output (security/perf), per env | new ERROR/WARN findings | profile **Database** ≠ none |
| Deploy | profile's deploy command (`vercel ls`, `/vercel:status`, …) | last prod/preview deploy not READY | profile **Deploy** ≠ none |
| Prod drift | profile's promotion path (sync log + newest local migration) | unmerged promotion, or a migration not yet promoted | profile **Prod promotion** ≠ none |

## Procedure

1. **Local state** — `git status -sb`, ahead/behind vs upstream. Note dirty/unpushed.
2. **PRs + CI** — `gh pr list` for open PRs; for each, read its latest CI run conclusion
   (`gh pr checks <n>` or `gh run list --branch <b>`). Flag failing/blocked/conflicting.
3. **Quality gates** — run **[VERIFY]** (fast ones first). Heavier suites (e2e) only if
   asked or a UI change is in flight. Report pass/fail with the first failing output, not
   a summary.
4. **Database** *(only if profile declares one)* — for **each environment**: compare the
   migrations dir against the applied list (pending = local file with no applied row) and
   read advisors (security + performance). Inspection only — never apply here. List
   pending migrations and any ERROR/WARN advisors.
5. **Deploy** *(only if profile declares a platform)* — latest prod + preview deploy state.
6. **Prod drift** *(only if profile declares a promotion path)* — is the newest local
   migration promoted? Any sync PR still open? How many app changes behind is prod?
7. **Verdict + remediation** — GREEN/YELLOW/RED, red first, then offer ONE fix.

## Output format

```
## 🩺 Project health — <GREEN ✅ | YELLOW ⚠️ | RED 🔴>

### 🔴 Needs attention
- <signal> — <what's red + the one-line fix>

### Checks
| Area | State |
|---|---|
| Working tree | clean · pushed |
| Open PRs / CI | #N <title> — CI ❌ <job> |
| lint / typecheck / test | ✅ / ✅ / ❌ (3 failing) |
| Migrations (staging) | 1 pending: <file>        (or: n/a) |
| Migrations (prod) | up to date                  (or: n/a) |
| Advisors (prod) | 2 WARN (rls_init_plan)        (or: n/a) |
| Deploy | prod READY · preview READY            (or: n/a) |
| Prod drift | prod 1 migration behind (PR #N open)  (or: n/a) |

### ✅ Recommended fix: <one thing>
<why + the exact hand-off>
```

Rows whose signal isn't configured in the profile render as **n/a**, not red.

## Remediation hand-offs (offer ONE)

| Red signal | Offer |
|---|---|
| CI failing on a PR | investigate the failing job (`gh run view --log-failed`), or watch/autofix the PR |
| lint/type/test failing | fix locally; `/code-review` the diff before pushing |
| Pending migration | apply it through the project's migration path (CLI / management API), **not** from this skill |
| New advisor ERROR/WARN | author an idempotent hardening migration (lowest environment first) |
| Prod behind dev | run the project's promotion flow to open the PR (e.g. a `synctoprod`-style skill) |
| Deploy not READY | inspect the deploy via the platform's status command / logs |

## Common Mistakes

- **Summarizing instead of showing.** "Tests fail" is useless — show the first failing
  test/output.
- **Mixing environments.** When the profile lists more than one (e.g. staging + prod),
  check each separately and label rows by environment; migrations flow lowest→highest,
  never reversed.
- **Applying a migration or deploying from this skill.** It's read-only diagnosis; hand
  off to the project's migration/promotion/deploy flow.
- **Calling it GREEN while prod has drifted.** An unpromoted migration or open sync PR is
  a YELLOW at minimum — call it out.
- **Marking an unconfigured signal red.** If the profile doesn't declare a DB / deploy /
  promotion path, that row is **n/a**, not a failure.
- **Drifting into spec progress.** Feature/milestone status is `/projectstatus`.
