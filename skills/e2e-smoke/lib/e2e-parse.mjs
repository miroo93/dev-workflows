// Stack-agnostic login-response parsing for the e2e smoke gate.
// The token field is configurable via E2E_TOKEN_PATH (a dot-path into the JSON
// response, e.g. "access_token" or "data.session.access_token"). Defaults to
// common token field names if unset.

function dig(obj, path) {
  return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
}

export function parseLoginResponse(body, tokenPath) {
  let data;
  try { data = JSON.parse(body); }
  catch { return { ok: false, reason: 'unparseable login response' }; }

  // Resolve the token: explicit configured path first, then common fallbacks.
  const candidates = tokenPath
    ? [tokenPath]
    : ['access_token', 'token', 'data.access_token', 'data.token', 'session.access_token'];

  for (const p of candidates) {
    const tok = dig(data, p);
    if (typeof tok === 'string' && tok.length > 0) {
      const out = { ok: true, token: tok };
      const role = (data.user && data.user.role) || dig(data, 'data.user.role');
      if (role) out.role = role;
      return out;
    }
  }
  return { ok: false, reason: (data && data.message) || 'login failed (no token in response)' };
}

export function classifyHttpStatus(code) {
  // Only HTTP 200 is a successful login; 201/204/etc. are intentionally rejected.
  if (code === 200) return { ok: true };
  if (code === 0) return { ok: false, reason: 'login endpoint unreachable' };
  if (code >= 500) return { ok: false, reason: `backend unavailable (HTTP ${code})` };
  if (code === 400 || code === 401 || code === 403) return { ok: false, reason: `invalid e2e credentials (HTTP ${code})` };
  return { ok: false, reason: `login failed (HTTP ${code})` };
}
