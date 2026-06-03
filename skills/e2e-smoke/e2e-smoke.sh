#!/usr/bin/env bash
# e2e-smoke.sh — stack-agnostic secret-sensitive plumbing for the e2e smoke gate.
# Subcommands: login | serve <worktree> | inject-snippet | teardown
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
  rm -f "$TOKEN_FILE" "$RESP_FILE" "$SNIPPET_FILE" "$LOGIN_SNIPPET_FILE" "$SCRATCH/.dev.log"
  echo "STATUS=OK scrubbed=true"
}

case "${1:-}" in
  login) cmd_login ;;
  serve) shift; cmd_serve "${1:-.}" ;;
  inject-snippet) cmd_inject_snippet ;;
  login-snippet) cmd_login_snippet ;;
  teardown) cmd_teardown ;;
  *) echo "usage: e2e-smoke.sh {login|serve <worktree>|inject-snippet|login-snippet|teardown}" >&2; exit 2 ;;
esac
