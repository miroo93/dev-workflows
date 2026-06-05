# Dev Workflows

Stack-agnostic, intent-based spec-driven-development workflows for Claude Code. The same
skills work on any stack (Next.js + Supabase, React + Vite, Rails, …) because everything
stack-specific lives in a per-project **stack profile** (`docs/stack.md`) that the skills read
at runtime instead of hardcoding a framework or build command.

## Skills

| Skill | Use when… |
|-------|-----------|
| `/feature` | Build a **new** feature end-to-end (brainstorm → grill → spec → clarify → plan → tasks → analyze gate → worktree → TDD build with per-task review → PR). |
| `/improve` | **Change/extend** an existing feature that works as specified. Amends the spec first, then a scope-matched build. |
| `/troubleshoot` | **Fix a bug** you hit while manually testing. Root-cause gate (no fix before root cause) → test-first fix → PR. |
| `/grill-me` | Stress-test a plan/design — relentless one-decision-at-a-time interview via `AskUserQuestion`. Used as a gate by `/feature` and `/improve`. |
| `e2e-smoke` | *(internal)* Real-browser smoke gate invoked by the three workflows. Returns PASS/FAIL/BLOCKED. |
| `/spec` `/plan` `/tasks` `/implement` | Thin entry points that defer to your spec layer (GitHub Spec-Kit if installed, plain markdown, or none). |
| `/analyze` `/checklist` `/tasks-to-issues` | More spec-layer entry points. `/analyze` = read-only cross-artifact consistency check (spec vs plan vs tasks) before coding — built into `/feature` (§4b) and `/improve` (§3b). `/checklist` = requirements-quality checklist ("unit tests for the English") for a risk dimension. `/tasks-to-issues` = export `tasks.md` to GitHub issues for human/distributed tracking (an alternative to the in-session build loop, not a step in it). |
| `/pr` | Get the current branch's work onto the **right** PR: checks the **live** PR status, rebases onto base, resolves conflicts, verifies, and pushes (`--force-with-lease`). Updates the open PR, or opens a **new** one if the branch's PR was already merged. |
| `/writing-skills` | Author or update the skills in this repo using TDD-for-skills (RED baseline → GREEN minimal skill → REFACTOR to close loopholes). Vendored from [Superpowers](https://github.com/obra/superpowers) — see `skills/writing-skills/ATTRIBUTION.md`. |

**Routing in one line:** new feature → `/feature` · change a working feature → `/improve` · wrong/broken behavior → `/troubleshoot`.

### The line between `/improve` and `/troubleshoot`
- `/improve` = **change correct behavior** (add/extend/modify a feature that works as specified).
- `/troubleshoot` = **fix incorrect behavior** (wrong value, broken interaction, error — or known-bad-by-design code like a hardcoded auth bypass).

---

## Install (from GitHub)

This repo is a **Claude Code plugin marketplace**. Add it once, then install the plugin:

```bash
# 1. Register this repo as a marketplace (use your repo's URL)
claude plugin marketplace add miroo93/dev-workflows
#    …or the full URL:
#    claude plugin marketplace add https://github.com/<you>/dev-workflows

# 2. Install the plugin from it
claude plugin install dev-workflows@dev-workflows
```

> The two `dev-workflows` are `<plugin-name>@<marketplace-name>` — both happen to be named
> the same here. Run these from inside the project where you want the skills (installs to
> the project), or with `--scope user` to make them available everywhere.

Install the prerequisites too (see below) — at minimum `superpowers`.

### Keeping projects up to date

Push updates to this repo, then in each consuming project:

```bash
claude plugin marketplace update dev-workflows   # pull the latest marketplace + plugin
claude plugin update dev-workflows               # apply the new version
```

Bump the `version` in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
when you publish a change, so `update` has a new version to move to. (A quick workflow: keep them
in lockstep, tag releases `v0.1.1`, etc.)

---

## Prerequisites

| Plugin / tool | Tier | Why |
|---------------|------|-----|
| [`superpowers`](https://github.com/obra/superpowers) | **Required** | The execution layer: `brainstorming`, `test-driven-development`, `systematic-debugging`, `subagent-driven-development`, `using-git-worktrees`, `finishing-a-development-branch`, `verification-before-completion`. |
| A spec layer | **Recommended** for `/feature` and `/improve` | Gives a durable contract + regression oracle. **Plain-markdown specs work out of the box with zero extra tooling** — the workflows now **always write a markdown `spec.md` by default** on any non-trivial run. GitHub Spec-Kit (`specify init`) is the heaviest option and remains **optional**: it just layers clarify/analyze machinery on top of the same markdown artifacts. |
| [`superpowers-chrome`](https://github.com/obra/superpowers-chrome) (or any Playwright MCP) | Optional | Browser control for reproduction + the `e2e-smoke` gate. Without it, the e2e gate is skipped. |
| A backend-log tool | Optional | `/troubleshoot` uses it for runtime/invocation bugs (e.g. `supabase functions logs`, `vercel logs`). Falls back to manual log inspection. |

> **The spec layer is not a prerequisite plugin.** Plain-markdown specs need nothing installed.
> Spec-Kit is **not** installed via `claude plugin` — it's `specify init` scaffolding you run in the
> project, so it never appears in the `claude plugin install` list below.

```bash
claude plugin marketplace add obra/superpowers-marketplace
claude plugin install superpowers@superpowers-marketplace
claude plugin install superpowers-chrome@superpowers-marketplace   # optional
```

---

## Setup (per consuming project)

1. **Install the plugin** (above).
2. **Create the stack profile.** Copy the template and fill it in:
   ```bash
   mkdir -p .sdd
   cp "$(claude plugin path dev-workflows)/templates/sdd-stack.template.md" docs/stack.md
   $EDITOR docs/stack.md
   ```
   (If `claude plugin path` isn't available, copy the template from this repo's
   `templates/sdd-stack.template.md`.) See `templates/examples/` for worked examples —
   including **`nextjs-supabase-vercel.stack.md`**.
3. **(Optional) Configure the e2e gate.** Fill the `E2E smoke gate` block in `docs/stack.md`,
   add `E2E_EMAIL`/`E2E_PASSWORD` to a **gitignored** `.env`, and add `.e2e-smoke/` + `.env`
   to `.gitignore`. Set `enabled: false` to skip the browser gate.

The skills read `docs/stack.md` for the framework, conventions, verify commands,
frozen patterns, spec location, backend-log tool, and e2e config.

---

## Adapting for a Next.js + Supabase + Vercel project

The full worked profile is in [`templates/examples/nextjs-supabase-vercel.stack.md`](templates/examples/nextjs-supabase-vercel.stack.md). The key adaptations:

- **Verify commands** → `npm run lint`, `npm run typecheck` (`tsc --noEmit`), `npm run build`, `npm test`.
- **Conventions to encode** (so the code-quality reviewer enforces them): Server vs Client component boundaries, RLS as the security boundary, no service-role key in the browser, `revalidatePath`/`revalidateTag` after Server-Action mutations, schema changes via `supabase/migrations`, `NEXT_PUBLIC_*` for client-exposed env only.
- **Binding context files** → add `supabase/migrations/` (schema source of truth) and your `database.types.ts`.
- **Backend-log tool** → `vercel logs <deployment>` + `supabase functions logs`, used by `/troubleshoot` for runtime bugs.
- **E2E auth mode** → use **`form-login`** (drive the real `/login` form). Supabase Auth uses cookie sessions, so the `token-injection` localStorage path usually doesn't apply unless you've built a custom JSON token endpoint. Set `app_url: http://localhost:3000` and `dev_command: npm run dev`.
- **Spec layer** → plain markdown (`docs/specs/**/spec.md`) is the lowest-friction choice; run `specify init` only if you want full Spec-Kit.

Drop that file in as `docs/stack.md`, tweak selectors/paths to your app, and the same `/feature` `/improve` `/troubleshoot` skills run unchanged.

---

## What the stack profile controls

The profile replaces everything the skills would otherwise hardcode:

- **Stack** line + **binding context files** → injected as `[PROJECT CONTEXT]` into every subagent prompt.
- **Conventions** + **frozen patterns** → what the code-quality reviewer enforces / refuses to touch.
- **Verify commands** → the lint/typecheck/build/test commands run at every quality gate (`[VERIFY]`).
- **Spec / planning layer** → how `/improve` and `/troubleshoot` locate a feature's spec, and which spec tooling `/feature` drives.
- **Backend-log tool** → the optional runtime-log branch in `/troubleshoot`.
- **E2E smoke gate** → auth mode (token-injection / form-login / none), app URL, dev command, selectors.

## Notes & limitations

- These skills **orchestrate** Superpowers skills by name. Without `superpowers`, the workflows lose their execution discipline (TDD loop, worktrees, branch finish) — install it.
- `skills/e2e-smoke/e2e-smoke.sh` supports **token-injection** auth out of the box (mint a token from a JSON login endpoint, inject into `localStorage`). **Form-login** and **public** apps are driven directly by the `e2e-smoke` skill via Playwright MCP using only the script's `serve`/`teardown`.
- The GitHub Spec-Kit `speckit-*` skills are **not** bundled — install Spec-Kit separately (`specify init`) if you want that layer. Otherwise the workflows default to plain-markdown specs (always written on non-trivial runs); Spec-Kit only adds clarify/checklist/analyze machinery on top. The `/spec`, `/plan`, `/tasks`, `/clarify`-equivalent, `/analyze`, `/checklist`, `/implement`, and `/tasks-to-issues` entry points defer to the matching `speckit-*` command when Spec-Kit is installed, and run a hand-rolled fallback otherwise.
- **Two Spec-Kit commands are deliberately NOT wired into the `/feature`/`/improve` loop:** `speckit-implement` (a competing executor — the Superpowers subagent TDD loop replaces it) and `speckit-taskstoissues` (issue export for distributed teams — an alternative to the in-session loop, exposed only as the standalone `/tasks-to-issues`).
- **Autonomous by default (answer upfront, then walk away).** `/feature` and `/improve` run **autonomously by default**: the interactive gates (grill + clarify, plus checklist scoping) are **front-loaded** into one block at the start, then the agent prints a **Decision Manifest** (resolved decisions + a deferred-decision policy) and runs to PR without per-step pauses. It stops only for the **stop-class** — schema/migrations, security/auth/secrets, frozen-pattern changes, and **one-way doors** (hard-to-reverse / costly-to-refactor choices). Ask to **"run slowly" / "stop at each step"** for **step-through** mode, which pauses at every step instead. (`/troubleshoot` is likewise autonomous after its mandatory diagnosis gate.) The split mirrors a hard rule: interactive steps (anything that asks *you*) run in the **main session**; non-interactive read-heavy steps (`analyze`, reviews) run in **subagents**.
- **Constitution = your stack profile.** Spec-Kit's `clarify`/`plan`/`analyze` read `/memory/constitution.md` (project principles) and treat violations as CRITICAL. In dev-workflows the stack profile's **Conventions** and **frozen patterns** (`docs/stack.md`) play that role. If you use Spec-Kit's `analyze`, keep a `constitution.md` in sync with those frozen patterns (or skip it and the constitution checks become no-ops) — don't maintain two divergent rule sources.

## License

MIT — see [LICENSE](LICENSE).
