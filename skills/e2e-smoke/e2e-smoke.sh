#!/usr/bin/env bash
# e2e-smoke.sh — stack-agnostic secret-sensitive plumbing for the e2e smoke gate.
# Subcommands: login | serve <worktree> | inject-snippet | login-snippet | teardown
#              wait-ready | bypass-snippet | auth-route-snippet      (preview target)
#
# All stack specifics come from environment variables (the calling skill exports
# them from the project's .sdd/stack.md "E2E smoke gate" block). Secrets
# (E2E_PASSWORD) reach only curl. The minted token → .e2e-smoke/.token (gitignored),
# never echoed.
#
# Required env (token-injection mode):
#   E2E_EMAIL, E2E_PASSWORD     — credentials (from gitignored .env)
#   E2E_LOGIN_ENDPOINT          — full URL of the login endpoint (vars already expanded)
#   E2E_TOKEN_PATH              — dot-path to the token in the JSON response (e.g. access_token)
#   E2E_STORAGE_KEYS            — comma-separated localStorage keys to set (e.g. access_token,token)
# Optional:
#   E2E_APP_URL                 — app base URL (default http://localhost:5173)
#   E2E_DEV_COMMAND             — dev server command (default "npm run dev")
#   E2E_EMAIL_FIELD             — JSON field name for email (default "email")
#   E2E_PASSWORD_FIELD          — JSON field name for password (default "password")
#
# Preview target (E2E_TARGET=preview) — test against a deployed Vercel preview URL
# instead of a local dev server. The calling skill resolves the preview URL for the
# PR's HEAD commit and exports it as E2E_APP_URL; this script then waits for it to be
# READY, plants the Deployment-Protection bypass cookie, and (for cookie-route auth)
# drives a preview-only test-auth route that Set-Cookies a Supabase session.
#   E2E_TARGET                  — local (default) | preview
#   E2E_PROTECTION_BYPASS       — Vercel "Protection Bypass for Automation" secret (from .env)
#   E2E_READY_TIMEOUT           — seconds to wait for the preview to serve 2xx/3xx (default 600)
#   E2E_AUTH_ROUTE              — path of the preview-only test-auth route (default /api/test-auth)
#   E2E_AUTH_ROUTE_SECRET       — bearer secret the route requires (from .env)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

APP_URL="${E2E_APP_URL:-http://localhost:5173}"
DEV_CMD="${E2E_DEV_COMMAND:-npm run dev}"
EMAIL_FIELD="${E2E_EMAIL_FIELD:-email}"
PASSWORD_FIELD="${E2E_PASSWORD_FIELD:-password}"
TOKEN_PATH="${E2E_TOKEN_PATH:-}"
STORAGE_KEYS="${E2E_STORAGE_KEYS:-access_token}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRATCH=".e2e-smoke"
TOKEN_FILE="$SCRATCH/.token"
RESP_FILE="$SCRATCH/.login-resp.json"
SNIPPET_FILE="$SCRATCH/inject.js"
LOGIN_SNIPPET_FILE="$SCRATCH/login.js"
BYPASS_SNIPPET_FILE="$SCRATCH/bypass.js"
AUTH_ROUTE_SNIPPET_FILE="$SCRATCH/auth-route.js"
CURL_CFG="$SCRATCH/.curlcfg"
DEVPID_FILE="$SCRATCH/.dev.pid"
mkdir -p "$SCRATCH"

load_env() {
  [ -f .env ] || { echo "STATUS=BLOCKED reason=.env missing"; exit 0; }
  set -a; . ./.env; set +a
  [ -n "${E2E_EMAIL:-}" ] && [ -n "${E2E_PASSWORD:-}" ] || { echo "STATUS=BLOCKED reason=E2E_EMAIL/E2E_PASSWORD not set"; exit 0; }
  [ -n "${E2E_LOGIN_ENDPOINT:-}" ] || { echo "STATUS=BLOCKED reason=E2E_LOGIN_ENDPOINT not set (token-injection mode)"; exit 0; }
}

load_form_env() {
  # Form-login mode: needs creds + the login path and field/submit selectors,
  # but NOT E2E_LOGIN_ENDPOINT (that is token-injection-only).
  [ -f .env ] || { echo "STATUS=BLOCKED reason=.env missing"; exit 0; }
  set -a; . ./.env; set +a
  [ -n "${E2E_EMAIL:-}" ] && [ -n "${E2E_PASSWORD:-}" ] || { echo "STATUS=BLOCKED reason=E2E_EMAIL/E2E_PASSWORD not set"; exit 0; }
  E2E_LOGIN_PATH="${E2E_LOGIN_PATH:-/login}"
  E2E_EMAIL_SELECTOR="${E2E_EMAIL_SELECTOR:-input[type=email]}"
  E2E_PASSWORD_SELECTOR="${E2E_PASSWORD_SELECTOR:-input[type=password]}"
  E2E_SUBMIT_SELECTOR="${E2E_SUBMIT_SELECTOR:-button[type=submit]}"
}

load_preview_env() {
  # Preview target: the preview URL must already be resolved by the caller and
  # exported as E2E_APP_URL. Secrets (bypass + route secret) come from gitignored .env.
  [ -n "${E2E_APP_URL:-}" ] || { echo "STATUS=BLOCKED reason=E2E_APP_URL (preview url) not set"; exit 0; }
  [ -f .env ] && { set -a; . ./.env; set +a; }
  return 0
}

cmd_login() {
  load_env
  local http
  # Build the JSON body from env vars and pipe it to curl via stdin (--data @-) so the
  # password never appears in curl's argv (not visible in `ps aux`).
  http=$(E2E_EMAIL="$E2E_EMAIL" E2E_PASSWORD="$E2E_PASSWORD" EF="$EMAIL_FIELD" PF="$PASSWORD_FIELD" \
    python3 -c 'import json,os;print(json.dumps({os.environ["EF"]:os.environ["E2E_EMAIL"],os.environ["PF"]:os.environ["E2E_PASSWORD"]}))' \
    | curl -s -o "$RESP_FILE" -w "%{http_code}" \
      -X POST "$E2E_LOGIN_ENDPOINT" \
      -H "Content-Type: application/json" \
      --data @- \
    || echo "000")
  TOKEN_PATH="$TOKEN_PATH" node -e '
    import(process.argv[4]).then(m => {
      const fs=require("fs");
      const cls=m.classifyHttpStatus(Number(process.argv[1]));
      if(!cls.ok){console.log("STATUS=BLOCKED reason="+cls.reason);process.exit(0);}
      const r=m.parseLoginResponse(fs.readFileSync(process.argv[2],"utf8"), process.env.TOKEN_PATH||undefined);
      if(!r.ok){console.log("STATUS=BLOCKED reason="+r.reason);process.exit(0);}
      fs.writeFileSync(process.argv[3], r.token);
      console.log("STATUS=OK role="+(r.role||"unknown"));
    });
  ' "$http" "$RESP_FILE" "$TOKEN_FILE" "$HERE/lib/e2e-parse.mjs"
  rm -f "$RESP_FILE"
}

cmd_serve() {
  local wt="${1:-.}"
  if [ "$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL" 2>/dev/null)" = "200" ]; then
    echo "STATUS=OK reused=true"; return
  fi
  # Run the dev command in its own process group (set -m) so teardown's process-group
  # kill reaches the grandchild server, not just the npm/wrapper process.
  ( set -m; cd "$wt" && eval "$DEV_CMD" >"$OLDPWD/$SCRATCH/.dev.log" 2>&1 & echo $! >"$OLDPWD/$DEVPID_FILE" )
  local i
  for i in $(seq 1 30); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL" 2>/dev/null)" = "200" ] && { echo "STATUS=OK reused=false waited=${i}s"; return; }
    sleep 1
  done
  echo "STATUS=BLOCKED reason=dev server did not come up in 30s"; exit 0
}

# --- preview target -------------------------------------------------------------

cmd_wait_ready() {
  # Poll the preview URL until it serves a 2xx/3xx, sending the Deployment-Protection
  # bypass header so a protected preview returns 200 instead of 401. The secret goes in
  # a gitignored curl config (header = ...), never in argv (so it stays out of `ps`).
  load_preview_env
  local timeout="${E2E_READY_TIMEOUT:-600}" i code=000
  : > "$CURL_CFG"; chmod 600 "$CURL_CFG"
  if [ -n "${E2E_PROTECTION_BYPASS:-}" ]; then
    printf 'header = "x-vercel-protection-bypass: %s"\n' "$E2E_PROTECTION_BYPASS" > "$CURL_CFG"
  fi
  for i in $(seq 1 "$timeout"); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -K "$CURL_CFG" "$APP_URL" 2>/dev/null || echo 000)
    case "$code" in 2*|3*) rm -f "$CURL_CFG"; echo "STATUS=OK code=$code waited=${i}s"; return ;; esac
    sleep 1
  done
  rm -f "$CURL_CFG"
  if [ "$code" = "401" ] || [ "$code" = "403" ]; then
    echo "STATUS=BLOCKED reason=preview still protected (code=$code) after ${timeout}s — check E2E_PROTECTION_BYPASS"
  else
    echo "STATUS=BLOCKED reason=preview not READY within ${timeout}s (last code=$code)"
  fi
  exit 0
}

cmd_bypass_snippet() {
  # Plant the Deployment-Protection bypass as a context cookie by navigating once with
  # ?x-vercel-protection-bypass=<secret>&x-vercel-set-bypass-cookie=true, then immediately
  # navigating to the clean base URL (so the returned url carries no secret). The cookie
  # then covers every later navigation/snippet in the same browser context. The secret is
  # baked into the gitignored snippet FILE and run by filename only.
  load_preview_env
  [ -n "${E2E_PROTECTION_BYPASS:-}" ] || { echo "STATUS=BLOCKED reason=E2E_PROTECTION_BYPASS not set in .env"; exit 0; }
  APP_URL="$APP_URL" SECRET="$E2E_PROTECTION_BYPASS" SNIPPET_FILE="$BYPASS_SNIPPET_FILE" python3 -c '
import json,os
base=os.environ["APP_URL"].rstrip("/")+"/"
sep="&" if "?" in base else "?"
seeded=base+sep+"x-vercel-protection-bypass="+os.environ["SECRET"]+"&x-vercel-set-bypass-cookie=true"
snip="""async (page) => {
  await page.goto(%s, { waitUntil: "domcontentloaded" });
  await page.goto(%s, { waitUntil: "domcontentloaded" });
  return { url: page.url(), title: await page.title() };
}""" % (json.dumps(seeded), json.dumps(base))
open(os.environ["SNIPPET_FILE"],"w").write(snip)
'
  echo "STATUS=OK snippet=$BYPASS_SNIPPET_FILE"
}

cmd_auth_route_snippet() {
  # cookie-route auth (strategy B): hit a preview-only test-auth route that mints a
  # Supabase session and Set-Cookies it server-side (@supabase/ssr cookies), then navigate
  # to the app already authenticated. The route's bearer secret is sent as a header, baked
  # into the gitignored snippet FILE and run by filename only — it never crosses the MCP
  # boundary as a tool argument. Assumes the bypass cookie is already planted (run
  # bypass-snippet first) so the route itself is reachable behind Deployment Protection.
  load_preview_env
  E2E_AUTH_ROUTE="${E2E_AUTH_ROUTE:-/api/test-auth}"
  [ -n "${E2E_AUTH_ROUTE_SECRET:-}" ] || { echo "STATUS=BLOCKED reason=E2E_AUTH_ROUTE_SECRET not set in .env"; exit 0; }
  local route_url="${APP_URL%/}/${E2E_AUTH_ROUTE#/}"
  APP_URL="$APP_URL" ROUTE_URL="$route_url" SECRET="$E2E_AUTH_ROUTE_SECRET" SNIPPET_FILE="$AUTH_ROUTE_SNIPPET_FILE" python3 -c '
import json,os
base=os.environ["APP_URL"].rstrip("/")+"/"
snip="""async (page) => {
  await page.setExtraHTTPHeaders({ "x-e2e-auth": %s });
  await page.goto(%s, { waitUntil: "domcontentloaded" });
  await page.setExtraHTTPHeaders({});
  await page.goto(%s, { waitUntil: "domcontentloaded" });
  await page.waitForTimeout(2000);
  return { url: page.url(), title: await page.title() };
}""" % (json.dumps(os.environ["SECRET"]), json.dumps(os.environ["ROUTE_URL"]), json.dumps(base))
open(os.environ["SNIPPET_FILE"],"w").write(snip)
'
  echo "STATUS=OK snippet=$AUTH_ROUTE_SNIPPET_FILE"
}

# --------------------------------------------------------------------------------

cmd_inject_snippet() {
  [ -f "$TOKEN_FILE" ] || { echo "STATUS=BLOCKED reason=no token (run login first)"; exit 0; }
  TOKEN_FILE="$TOKEN_FILE" SNIPPET_FILE="$SNIPPET_FILE" APP_URL="$APP_URL" STORAGE_KEYS="$STORAGE_KEYS" python3 -c '
import json,os
tok=open(os.environ["TOKEN_FILE"]).read().strip()
keys=[k.strip() for k in os.environ["STORAGE_KEYS"].split(",") if k.strip()]
url=os.environ["APP_URL"].rstrip("/")+"/"
snip="""async (page) => {
  const tok = %s;
  const keys = %s;
  await page.addInitScript((args)=>{try{for(const k of args.keys){localStorage.setItem(k,args.tok);}}catch(e){}}, { tok, keys });
  await page.goto(%s, { waitUntil: "domcontentloaded" });
  await page.waitForTimeout(3000);
  return { url: page.url(), title: await page.title() };
}""" % (json.dumps(tok), json.dumps(keys), json.dumps(url))
open(os.environ["SNIPPET_FILE"],"w").write(snip)
'
  echo "STATUS=OK snippet=$SNIPPET_FILE"
}

cmd_login_snippet() {
  # Form-login mode: write a gitignored Playwright page-driver that navigates to the
  # login page and fills email+password, then submits. The password is baked into the
  # snippet FILE here (read from .env) and run by FILENAME only via browser_run_code_unsafe,
  # so the literal secret never crosses the Playwright MCP boundary or the transcript —
  # the same discipline the token uses via inject.js.
  load_form_env
  local login_url="${APP_URL%/}/${E2E_LOGIN_PATH#/}"
  E2E_EMAIL="$E2E_EMAIL" E2E_PASSWORD="$E2E_PASSWORD" \
  EMAIL_SEL="$E2E_EMAIL_SELECTOR" PASS_SEL="$E2E_PASSWORD_SELECTOR" SUBMIT_SEL="$E2E_SUBMIT_SELECTOR" \
  LOGIN_URL="$login_url" SNIPPET_FILE="$LOGIN_SNIPPET_FILE" python3 -c '
import json,os
snip="""async (page) => {
  await page.goto(%s, { waitUntil: "domcontentloaded" });
  await page.fill(%s, %s);
  await page.fill(%s, %s);
  await page.click(%s);
  await page.waitForLoadState("networkidle").catch(()=>{});
  await page.waitForTimeout(2000);
  return { url: page.url(), title: await page.title() };
}""" % (
  json.dumps(os.environ["LOGIN_URL"]),
  json.dumps(os.environ["EMAIL_SEL"]), json.dumps(os.environ["E2E_EMAIL"]),
  json.dumps(os.environ["PASS_SEL"]), json.dumps(os.environ["E2E_PASSWORD"]),
  json.dumps(os.environ["SUBMIT_SEL"]),
)
open(os.environ["SNIPPET_FILE"],"w").write(snip)
'
  echo "STATUS=OK snippet=$LOGIN_SNIPPET_FILE"
}

cmd_teardown() {
  if [ -f "$DEVPID_FILE" ]; then
    _pid="$(cat "$DEVPID_FILE")"
    kill -- "-$_pid" 2>/dev/null || kill "$_pid" 2>/dev/null || true
    rm -f "$DEVPID_FILE"
  fi
  rm -f "$TOKEN_FILE" "$RESP_FILE" "$SNIPPET_FILE" "$LOGIN_SNIPPET_FILE" \
        "$BYPASS_SNIPPET_FILE" "$AUTH_ROUTE_SNIPPET_FILE" "$CURL_CFG" "$SCRATCH/.dev.log"
  echo "STATUS=OK scrubbed=true"
}

case "${1:-}" in
  login) cmd_login ;;
  serve) shift; cmd_serve "${1:-.}" ;;
  inject-snippet) cmd_inject_snippet ;;
  login-snippet) cmd_login_snippet ;;
  wait-ready) cmd_wait_ready ;;
  bypass-snippet) cmd_bypass_snippet ;;
  auth-route-snippet) cmd_auth_route_snippet ;;
  teardown) cmd_teardown ;;
  *) echo "usage: e2e-smoke.sh {login|serve <worktree>|inject-snippet|login-snippet|wait-ready|bypass-snippet|auth-route-snippet|teardown}" >&2; exit 2 ;;
esac
