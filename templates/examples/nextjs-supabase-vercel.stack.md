# SDD Stack Profile — Next.js + Supabase + Vercel — EXAMPLE

> A worked example of `.sdd/stack.md` for a Next.js (App Router) + Supabase project
> deployed on Vercel. Copy this to `.sdd/stack.md` in your project and adjust the
> bracketed bits to match your actual conventions.

## Stack

- **Runtime / framework:** Next.js 14+ (App Router), React Server Components + Client Components
- **Language:** TypeScript
- **Data / backend:** Supabase (Postgres + Auth + Row Level Security); access via `@supabase/supabase-js` and `@supabase/ssr`; mutations through Server Actions / Route Handlers
- **Styling:** Tailwind CSS v4 (design tokens), shadcn/ui primitives
- **State / data-fetching:** Server Components for reads; TanStack Query (or SWR) for client-side fetching/cache; Server Actions for writes

## Binding context files

- `CLAUDE.md` <!-- or AGENTS.md -->
- `docs/conventions.md` <!-- your conventions doc; delete if you don't have one -->
- `supabase/migrations/` <!-- the source of truth for the DB schema; read before touching data shape -->

## Conventions (the things reviewers must enforce)

- **Server vs Client components:** default to Server Components; add `"use client"` only when you need interactivity/hooks. Never import server-only code (service-role key, `cookies()`) into a Client Component.
- **Data access:** reads in Server Components or Route Handlers; writes via Server Actions. Never call Supabase with the service-role key from the browser.
- **Auth:** get the session via the server Supabase client (`createServerClient` + `cookies()`), or the `useUser()`/`useSession()` hook on the client — never hand-roll token parsing.
- **RLS is the security boundary:** every table has Row Level Security policies; never bypass RLS with the service-role key in user-facing paths. New tables ship with policies in the same migration.
- **Cache invalidation:** after a mutation, call `revalidatePath()`/`revalidateTag()` (server) or invalidate the relevant TanStack Query key (client). Never leave stale data.
- **Styling:** design-token Tailwind classes only — no arbitrary values (`bg-[#hex]`, `w-[327px]`).
- **Schema changes go through migrations:** never edit the DB by hand; add a `supabase/migrations/*.sql` file and run it. Keep generated types (`database.types.ts`) in sync.
- **Env vars:** client-exposed vars are `NEXT_PUBLIC_*` only; secrets (service-role key) are server-only and never logged.

## Frozen patterns (change only with explicit user authorization)

<!-- List any load-bearing code. Examples — replace with yours, or write "none": -->
- `lib/supabase/middleware.ts` — session refresh in Next.js middleware; ordering is fragile. Do not reorder cookie handling.
- <e.g. a debounced autosave, a webhook signature check, a rate limiter>

## Verify commands

```bash
npm run lint            # next lint / eslint
npm run typecheck       # tsc --noEmit   (or: npx tsc --noEmit)
npm run build           # next build
npm test                # vitest run / jest --ci  (delete if no test suite yet)
```

## Spec / planning layer

<!-- Pick what you actually use. Plain markdown is the lowest-friction option. -->
- **Spec location glob:** `docs/specs/**/spec.md` <!-- or specs/**/spec.md, or "none" -->
- **Spec tooling:** plain markdown <!-- or GitHub Spec-Kit (.specify/) if you run `specify init` -->
- **Branch naming:** `feature/<slug>`, `improve/<feature>-<slug>`, `fix/<feature>-<slug>`

## Backend log / runtime troubleshooting tool

- **Backend-log tool:** `vercel logs <deployment-url>` for Next.js/Edge/serverless function logs; `supabase functions logs <fn>` for Edge Functions; Supabase dashboard → Logs for Postgres/Auth. (For local dev, the `next dev` terminal output.)

## E2E smoke gate

> Supabase Auth typically issues a session via cookies, not a simple bearer token in
> localStorage — so `form-login` is usually the right mode here (drive the real login
> form). Use `token-injection` only if you have a custom JSON login endpoint that returns
> an access token you can place in storage.

```yaml
enabled: true
app_url: http://localhost:3000
dev_command: npm run dev
auth_mode: form-login
form_login:
  login_path: /login
  email_selector: input[name="email"]
  password_selector: input[name="password"]
  submit_selector: button[type="submit"]
  env_vars: [E2E_EMAIL, E2E_PASSWORD]
authed_assert_selector: 'nav[aria-label="Main"]'   # an element only shown when logged in
baseline_console_ignore: []                          # add known-benign console errors here
```

<!-- Alternative if you DO expose a JSON token endpoint:
auth_mode: token-injection
token_injection:
  login_endpoint: http://localhost:3000/api/auth/login
  request_fields: { email: "email", password: "password" }
  token_response_path: access_token        # or data.session.access_token for raw Supabase
  storage_keys: ["sb-access-token"]
  env_vars: [E2E_EMAIL, E2E_PASSWORD]
-->

## Prerequisite plugins

- `superpowers` (required)
- `superpowers-chrome` (optional — for the e2e gate)
- A spec layer is optional; plain markdown specs work out of the box.
