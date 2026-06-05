# SDD Stack Profile

> **What this is:** the per-project configuration that the `dev-workflows` skills
> (`feature`, `improve`, `troubleshoot`, `e2e-smoke`) read so they stay stack-agnostic.
> Copy this file to **`.sdd/stack.md`** in your project root and fill every section in.
> The skills look for it there first, then at `sdd-stack.md` in the repo root.
>
> Anything left as a `<…>` placeholder means the skills will ask you or fall back to a
> generic default. Fill in what you know; leave the rest.

---

## Stack

<!-- One or two lines naming the runtime, framework, data layer, styling, and backend.
     Example: "Next.js 14 (App Router) + TypeScript; Supabase (Postgres + Auth);
     Tailwind v4; server actions for mutations; Vitest for unit tests." -->

- **Runtime / framework:** <e.g. Next.js 14 App Router, or React 18 + Vite, or Rails 7>
- **Language:** <e.g. TypeScript, Python, Ruby>
- **Data / backend:** <e.g. Supabase, Prisma + Postgres, REST API, BaaS SDK>
- **Styling:** <e.g. Tailwind v4 tokens, CSS Modules, styled-components, none>
- **State / data-fetching:** <e.g. TanStack Query, RTK, server components, none>

## Binding context files

> Files the agent MUST read before doing anything. The skills will read these verbatim.

- `CLAUDE.md` <!-- or AGENTS.md / GEMINI.md — your project instructions -->
- <path to any architecture/conventions doc, e.g. docs/conventions.md>
- <path to a constitution/principles file if you use Spec-Kit, e.g. .specify/memory/constitution.md — else delete this line>

## Conventions (the things reviewers must enforce)

> Replace these with YOUR project's hard rules. The code-quality reviewer reads this list.

- <e.g. Styling: design-token classes only, no arbitrary values>
- <e.g. File-size limit: split components approaching N lines>
- <e.g. Data access: always go through the repository layer, never raw SQL in components>
- <e.g. Auth: use the `useSession()` hook, never call the auth client directly in components>
- <e.g. After every mutation, invalidate/revalidate the affected query/cache key>
- <e.g. Never write a field that isn't in the schema — note any silent-drop behavior here>

## Frozen patterns (change only with explicit user authorization)

> Intentionally-fragile or load-bearing code that must NOT be casually refactored.
> List file:area + why. If none, write "none".
>
> **These conventions + frozen patterns ARE your project's "constitution."** If you use
> GitHub Spec-Kit, its `clarify`/`plan`/`analyze` commands read `/memory/constitution.md`
> (project principles) and treat a violation as CRITICAL. Keep that file in sync with this
> list (or generate it from this list) so the analyze gate has principles to check — and do
> NOT maintain two divergent rule sources. If you don't use Spec-Kit, this list alone is the
> constitution; it flows into every subagent as `[PROJECT CONTEXT]`.

- <e.g. src/pages/Editor.jsx auto-save debounce + merge — prevents concurrent-write races; do not simplify>

## Verify commands

> The exact commands the skills run at every quality gate. These replace the hardcoded
> `npm run lint && npm run build`. List in the order they should run.

```bash
# lint
<e.g. npm run lint>
# typecheck / build
<e.g. npm run build>
# unit/integration test suite
<e.g. npm test -- --run>
```

## Spec / planning layer (optional)

> How specs are organized, if you use a spec-driven layer. The `improve`/`troubleshoot`
> skills search here to find a feature's spec. If you don't use specs, write "none" and
> the skills will operate without a spec oracle.

- **Spec location glob:** <e.g. specs/**/spec.md, or docs/features/*.md, or "none">
- **Spec tooling:** <e.g. GitHub Spec-Kit (.specify/), or plain markdown, or none>
- **Branch naming:** <e.g. feature/<slug>, fix/<slug>, improve/<slug>>

## Backend log / runtime troubleshooting tool (optional)

> Used by `troubleshoot` for backend/runtime bugs. If your stack has a log-pulling
> skill or CLI, name it here; otherwise the skill falls back to generic log inspection.

- **Backend-log tool:** <e.g. a `base44:base44-troubleshooter` skill, `supabase functions logs`,
  `vercel logs`, `heroku logs --tail`, or "none — inspect logs manually">

## E2E smoke gate (optional)

> Config for the real-browser smoke check (`e2e-smoke` skill). If you don't want a
> browser gate, set `enabled: false` and the calling skills will skip it.
> Secrets (password) live ONLY in a gitignored `.env`, never here.

```yaml
enabled: <true|false>
app_url: <e.g. http://localhost:5173 or http://localhost:3000>
dev_command: <e.g. npm run dev>
# How the smoke script authenticates. Pick ONE auth_mode and fill its block.
auth_mode: <none | token-injection | form-login>

# token-injection: mint a token via an HTTP login endpoint, inject into localStorage.
token_injection:
  login_endpoint: <e.g. ${APP_BASE_URL}/api/auth/login>
  # JSON field names the endpoint expects and the token field it returns:
  request_fields: { email: "email", password: "password" }
  token_response_path: <e.g. access_token  (dot-path into the JSON response)>
  # localStorage keys to set with the minted token (one or more):
  storage_keys: [<e.g. "access_token">]
  env_vars: [E2E_EMAIL, E2E_PASSWORD]   # read from gitignored .env

# form-login: drive the login form in the browser instead of minting a token.
form_login:
  login_path: <e.g. /login>
  email_selector: <e.g. input[name=email]>
  password_selector: <e.g. input[name=password]>
  submit_selector: <e.g. button[type=submit]>
  env_vars: [E2E_EMAIL, E2E_PASSWORD]

# A selector that only renders when authenticated (used to assert login worked):
authed_assert_selector: <e.g. nav[aria-label="Main"], or text "Settings">
# Console errors to ignore as baseline noise (substring match):
baseline_console_ignore: [<e.g. "manifest.json">]
```

## Prerequisite plugins

> These skills orchestrate other skills. Install these for full functionality:
> - `superpowers` (required) — brainstorming, TDD, systematic-debugging, worktrees,
>   subagent-driven-development, finishing-a-development-branch, verification.
> - `superpowers-chrome` (optional) — browser control for reproduction/e2e.
> - A spec layer (optional) — e.g. GitHub Spec-Kit, if "Spec / planning layer" above uses one.
