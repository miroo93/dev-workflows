---
name: e2e-smoke
description: Internal skill invoked by /feature, /improve, /troubleshoot to run a local real-browser smoke check against the running app and return PASS/FAIL/BLOCKED. Not user-invocable.
user-invocable: false
---

# e2e-smoke

Runs a real-browser smoke check of the running app and returns a verdict the caller
soft-gates on. Logs in (per the stack profile's auth mode), drives a per-change checklist
with Playwright MCP, captures evidence, tears down.

This skill is **stack-agnostic** — all app specifics come from the project's **stack profile**
(`docs/stack.md`, the `E2E smoke gate` block). If that block is `enabled: false` or missing,
the calling skill skips the e2e gate entirely.

## Inputs (from the calling skill)
- `FEATURE_DIRECTORY` — for the spec's acceptance criteria (checklist source)
- `WORKTREE_PATH` — where to run the dev server (default repo root)
- `SMOKE_FOCUS` — short description of what changed (routes/interactions to exercise)

## Config (from the stack profile's E2E smoke gate block)
- `target` (`local` — default | `preview`) — `local` serves a dev server; `preview` runs against a deployed Vercel preview URL (no local server). See "Procedure (preview target)".
- `app_url`, `dev_command`, `auth_mode` (`token-injection` | `form-login` | `cookie-route` | `none`)
- token-injection: `login_endpoint`, `token_response_path`, `storage_keys`, `request_fields`, `env_vars`
- form-login: `login_path`, `email_selector`, `password_selector`, `submit_selector`, `env_vars`
- cookie-route (preview-friendly, SSR-cookie auth): `auth_route` (default `/api/test-auth`), `auth_route_secret_env` — a preview-only route that mints a session and Set-Cookies it server-side
- preview target: `vercel_project`, `preview_url_source` (`github-deployment` | `vercel-cli` | `env`), `protection_bypass_env`, `ready_timeout_s`
- `authed_assert_selector` — element that only renders when authenticated
- `baseline_console_ignore` — console-error substrings to ignore as baseline noise

## Secret-handling rules (BINDING)
- The password lives only in gitignored `.env` and is read **only inside `e2e-smoke.sh`** (token-injection: it reaches `curl`; form-login: it is baked into the gitignored `.e2e-smoke/login.js` snippet by the script). **Never pass the password as an argument to a Playwright MCP tool** (e.g. `browser_fill_form`, `browser_type`) — the MCP echoes tool arguments into the transcript. In form-login mode you fill the password via the script-generated `login.js` snippet, run **by filename**, so the literal never crosses the MCP boundary. Never print the password.
- The minted token lives only in gitignored `.e2e-smoke/.token`, is injected via the gitignored `.e2e-smoke/inject.js` snippet, and is scrubbed in teardown.
- Do not `cat`/echo the token, the inject snippet, or the login snippet. Run snippets by **filename** only.
- **Preview secrets** (`E2E_PROTECTION_BYPASS`, `E2E_AUTH_ROUTE_SECRET`) live only in gitignored `.env`. The bypass secret reaches `curl` via a gitignored config file (`header = …`), never argv; both are baked into the gitignored `bypass.js` / `auth-route.js` snippets, run **by filename** only. Never print them, and never pass them as Playwright MCP tool arguments.
- Add `.e2e-smoke/` and `.env` to `.gitignore` if not already present.

## Step 0 — Load config from the stack profile (REQUIRED FIRST)
**Read `docs/stack.md` and parse its `E2E smoke gate` block before anything else.** If the block is `enabled: false` or the file/block is missing, return `BLOCKED` reason "e2e gate not configured" (the caller decides whether that's a skip). Otherwise read `auth_mode` and branch to the matching procedure below.

Map profile keys → env vars you export (token-injection):

| Profile key | Env var | Notes |
|---|---|---|
| `app_url` | `E2E_APP_URL` | default `http://localhost:5173` |
| `dev_command` | `E2E_DEV_COMMAND` | default `npm run dev` |
| `login_endpoint` | `E2E_LOGIN_ENDPOINT` | expand any `env_vars` first; **no default — required** |
| `token_response_path` | `E2E_TOKEN_PATH` | dot-path into the login JSON (e.g. `data.access_token`) |
| `storage_keys` | `E2E_STORAGE_KEYS` | comma-separated localStorage keys |
| `request_fields.email` | `E2E_EMAIL_FIELD` | only if the login JSON field isn't `email` |
| `request_fields.password` | `E2E_PASSWORD_FIELD` | only if not `password` |

`E2E_EMAIL` / `E2E_PASSWORD` come from the gitignored `.env` (the script sources it — do not export them). For the form-login key→env mapping, see the form-login section below.

> **`${CLAUDE_PLUGIN_ROOT}`** should resolve to this plugin's root. If it is unset in your shell, fall back to the absolute path of the directory containing this `SKILL.md` (the script is the sibling `e2e-smoke.sh`).

## The script
The plumbing script ships alongside this skill at `${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh`.
Export the config (token-injection) before calling it:

```bash
export E2E_APP_URL="<app_url>"
export E2E_DEV_COMMAND="<dev_command>"
export E2E_LOGIN_ENDPOINT="<login_endpoint, vars expanded>"
export E2E_TOKEN_PATH="<token_response_path>"
export E2E_STORAGE_KEYS="<storage_keys, comma-separated>"
# Only if the login JSON uses non-default field names:
# export E2E_EMAIL_FIELD="<email field>"   # default "email"
# export E2E_PASSWORD_FIELD="<password field>"  # default "password"
# E2E_EMAIL / E2E_PASSWORD come from the project's gitignored .env (the script sources it)
```

## Procedure (token-injection mode)
1. **Login.** Run `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh login`. Parse its `STATUS=` line. If `BLOCKED`, skip to step 7 and return `BLOCKED` with the reason (invalid creds, backend unavailable, missing config).
2. **Serve.** Run `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh serve "$WORKTREE_PATH"`. If `BLOCKED` (dev server didn't start), return `BLOCKED`.
3. **Inject snippet.** Run `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh inject-snippet`.
4. **Boot authenticated app.** Call Playwright MCP `browser_run_code_unsafe` with `filename: .e2e-smoke/inject.js`. **Do NOT `browser_navigate` to the app first** — the snippet's `addInitScript` must set the token *before* the page loads, and the snippet does its own `page.goto`. (The snippet's `filename` is resolved relative to the repo root, where the script wrote it; if the Playwright MCP server reports file-not-found, pass the absolute path `$WORKTREE_PATH/.e2e-smoke/inject.js`.) Then `browser_snapshot`. **Assert the authenticated shell**: the page URL is still the app URL (NOT redirected to a login route) AND the profile's `authed_assert_selector` is present. If it redirected to login or shows the auth-required state → return `BLOCKED` reason "token rejected / not authenticated" (env/credential issue, not a code FAIL).
5. **Drive the checklist.** Derive 3–6 concrete steps from `FEATURE_DIRECTORY`'s acceptance criteria + `SMOKE_FOCUS`: navigate to each changed route, perform the key interaction, assert the observable outcome via `browser_snapshot`. Throughout, collect `browser_console_messages` (level error) and watch for failed network requests on the exercised paths. ("NEW" error = any error-level console message whose text does NOT match a substring in `baseline_console_ignore`; there is no separate pre-change baseline capture — the ignore-list IS the baseline.)
6. **Evidence + verdict.**
   - `PASS` — every checklist step's expected outcome observed AND no NEW console error on the change's path (ignore substrings in `baseline_console_ignore`).
   - `FAIL` — a step's expected outcome did not appear, OR a non-baseline console/network error fired on the change's path. Capture a `browser_take_screenshot` (to `.e2e-smoke/`, which is scrubbed) and include the failing step + the error text in the return.
7. **Teardown.** `browser_close`, then `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh teardown` (kills only a dev server this run started; scrubs token + snippet).

## Procedure (form-login mode)
The script's `login`/`inject-snippet` are token-injection-specific. For form-login, export the form-login config and use `serve`/`login-snippet`/`teardown`:
```bash
export E2E_APP_URL="<app_url>"
export E2E_DEV_COMMAND="<dev_command>"
export E2E_LOGIN_PATH="<login_path>"                 # default /login
export E2E_EMAIL_SELECTOR="<email field selector>"   # default input[type=email]
export E2E_PASSWORD_SELECTOR="<password selector>"   # default input[type=password]
export E2E_SUBMIT_SELECTOR="<submit selector>"       # default button[type=submit]
# E2E_EMAIL / E2E_PASSWORD come from the gitignored .env (the script sources it)
```
1. **Serve.** `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh serve "$WORKTREE_PATH"`. If `BLOCKED`, return `BLOCKED`.
2. **Build login snippet.** `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh login-snippet`. This writes the gitignored `.e2e-smoke/login.js` page-driver with the password baked in from `.env`. If `BLOCKED` (`.env`/creds missing), return `BLOCKED`. **Never read or echo `login.js` — run it by filename only.**
3. **Log in.** Call Playwright MCP `browser_run_code_unsafe` with `filename: .e2e-smoke/login.js` (it navigates to the login page, fills + submits). The password never appears as a tool argument. Then `browser_snapshot` and **assert the authenticated shell** exactly as token-injection step 4: URL is NOT a login route AND `authed_assert_selector` present. If still on login / auth-required → return `BLOCKED` reason "login rejected / not authenticated" (env/credential issue, not a code FAIL).
4. **Drive the checklist → verdict → teardown** exactly as token-injection steps 5–7.

## Procedure (auth_mode: none)
Public app — skip login/inject; serve, drive the checklist on the changed routes, verdict, teardown.

## Procedure (preview target)
When the profile sets `target: preview`, test the **deployed Vercel preview** for the PR's HEAD commit instead of a local dev server. There is **no `serve`/`teardown` of a dev server** — `app_url` becomes the resolved preview URL, and Deployment Protection is bypassed with a cookie before any auth runs. Use this only on a branch that has an open PR (so a preview deployment exists).

**0. Resolve the preview URL** (per `preview_url_source`) and export it as `E2E_APP_URL`:
   - `github-deployment` (default, best for web sessions): read the PR's deployments/commit-statuses via the GitHub MCP tools, find the **Preview** environment deployment for the current HEAD SHA, take its `target_url`. If none yet, the deploy hasn't started → `BLOCKED` reason "no preview deployment for HEAD".
   - `vercel-cli`: `vercel ls <vercel_project> --environment=preview --token=$VERCEL_TOKEN` (or `vercel inspect`) filtered to the HEAD SHA.
   - `env`: caller already set `E2E_PREVIEW_URL`/`E2E_APP_URL`.
   Then export the target config (the bypass secret is sourced from gitignored `.env`):
   ```bash
   export E2E_TARGET="preview"
   export E2E_APP_URL="<resolved preview url>"
   export E2E_READY_TIMEOUT="<ready_timeout_s, default 600>"
   # E2E_PROTECTION_BYPASS (Vercel Protection-Bypass-for-Automation secret) from gitignored .env
   ```
1. **Wait for READY.** `bash ${CLAUDE_PLUGIN_ROOT}/skills/e2e-smoke/e2e-smoke.sh wait-ready`. Polls the preview (sending the bypass header from `.env`) until it serves 2xx/3xx. `BLOCKED` if it never becomes ready in `ready_timeout_s`, or stays 401/403 (bad/missing bypass secret).
2. **Plant the bypass cookie.** `bash …/e2e-smoke.sh bypass-snippet`, then call Playwright MCP `browser_run_code_unsafe` with `filename: .e2e-smoke/bypass.js`. This navigates once with the bypass query param (`x-vercel-set-bypass-cookie=true`) so the cookie covers the whole browser context, then returns to the clean URL. (If `auth_mode: none`, skip step 3.)
3. **Authenticate** against the preview origin:
   - **cookie-route** (recommended for `@supabase/ssr`): `bash …/e2e-smoke.sh auth-route-snippet`, then `browser_run_code_unsafe` with `filename: .e2e-smoke/auth-route.js`. It sends the route secret as a header (baked into the snippet file, run by filename — never a tool arg) to the preview-only `auth_route`, which Set-Cookies a Supabase session, then navigates to the app. **Assert the authenticated shell** (URL not a login route AND `authed_assert_selector` present); else `BLOCKED` reason "test-auth route did not authenticate".
   - **token-injection / form-login**: run `inject-snippet` / `login-snippet` exactly as the local procedures — the only difference is `E2E_APP_URL` is the preview URL and the bypass cookie is already planted. (Note: localStorage token-injection does **not** satisfy `@supabase/ssr` cookie sessions — use cookie-route for SSR apps.)
4. **Drive the checklist → verdict** exactly as token-injection steps 5–6.
5. **Teardown.** `browser_close`, then `bash …/e2e-smoke.sh teardown` (no dev server was started; this just scrubs the snippets + curl config). Deployment Protection's bypass cookie lives only in the closed browser context.

> **Honest scope:** preview testing exercises the real deployed artifact (Vercel runtime, RSC/middleware, real backend) but does **not** solve auth on its own — an SMS/phone-OTP app still needs a deterministic test-auth path (the preview-only `auth_route` above, or a fixed-OTP test user). A `BLOCKED` here is never a `PASS` (see soft-gate contract).

## Return (to the caller)
One block:
```
E2E_VERDICT: PASS | FAIL | BLOCKED
SMOKE_STEPS: <the checklist you ran>
FAILED_STEP: <only if FAIL>
EVIDENCE: <console/network error text; screenshot path if FAIL>
BLOCKED_REASON: <only if BLOCKED>
```

## Soft-gate contract (how callers MUST treat the verdict)
- `PASS` → proceed.
- `FAIL` → block PR-ready; surface FAILED_STEP + EVIDENCE to the user; do not open the PR until fixed or the user explicitly overrides.
- `BLOCKED` → surface BLOCKED_REASON; ask the user whether to proceed without the e2e check. NEVER silently skip.

**BLOCKED is not a PASS.** It means the check did not run, so you have no signal — treat it as "unverified," never as "verified enough." You may not open the PR or proceed on a BLOCKED (or FAIL) verdict without an **explicit user override**. Noting the reason in the PR description, or judging the cause to be "just infra / not my code," does **not** substitute for asking — the *ask* is the gate, not the mention. "Surface" means surface **and** wait for the user's decision.

## Notes
- Only Chromium via Playwright MCP. No committed Playwright specs (ad-hoc by design).
- Requires the `superpowers-chrome` plugin (or any Playwright MCP server) for `browser_*` tools.
