# idclear VPS testing deploy — reference

Companion to [SKILL.md](./SKILL.md). Commands run from the developer machine unless noted.

## Smoke checks

Save as a one-off script or run inline. Expects HTTPS on `testing.idclear.com`. No auth secrets required — status codes only.

```bash
devenv shell -- bash -c '
HOST="https://testing.idclear.com"
fail=0

code_only() {
  local name="$1" url="$2" allowed="$3"
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 "$url")
  if echo "$allowed" | grep -qw "$code"; then
    echo "PASS $name ($code) $url"
  else
    echo "FAIL $name ($code, want: $allowed) $url"
    fail=1
  fi
}

follow() {
  local name="$1" url="$2" allowed="$3"
  code=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 30 "$url")
  if echo "$allowed" | grep -qw "$code"; then
    echo "PASS $name ($code) $url"
  else
    echo "FAIL $name ($code, want: $allowed) $url"
    fail=1
  fi
}

# Core
code_only healthz "$HOST/healthz" "200"

# App surfaces (may redirect to Logto — 302/307 acceptable)
follow home "$HOST/" "200 302 307"
follow demo_volturapay "$HOST/demo/volturapay" "200 302 307"
follow my_data "$HOST/my-data-and-documents" "200 302 307"

# Auth surfaces. The route is /auth/login — there is no /auth/sign-in page.
# The only sign-in artifact is the API route below.
follow auth_login "$HOST/auth/login" "200 302 307"
follow auth_register "$HOST/auth/register" "200 302 307"
follow auth_welcome "$HOST/auth/welcome" "200 302 307"
follow auth_logto_api "$HOST/api/auth/logto-sign-in" "200 302 307"

# Static / Next assets. Bare path 404s; the trailing slash 308-redirects.
code_only next_internal "$HOST/_next/static" "200 404"

exit $fail
'
```

Adjust allowed codes if Logto or routing changes. For authenticated flows, use Playwright e2e against the deployed URL instead.

### Checks deliberately not here

| Check | Why it was removed |
|-------|--------------------|
| `https://api.testing.idclear.com/health` | No `api.` subdomain is configured in `docker-compose*.yml` or `apps/traefik/` for this host. It returns Cloudflare 522 (no origin) always — a permanent false failure, not a signal. |
| `$HOST/auth/sign-in` | That page does not exist on `staging`. Real pages are `/auth/login`, `/auth/register`, `/auth/sign-up`, `/auth/welcome`. |
| `$HOST/_next/static/` (trailing slash) | Returns 308, a trailing-slash redirect. The bare path is checked instead. |

## Service status

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"'
```

Key services: `test-nextjs`, `temporal-worker`, `traefik`, `yb-pg`, `logto`.

## Logs

```bash
# test-nextjs (API / portal / onboarding errors)
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose logs test-nextjs --tail 100'

# temporal-worker (async jobs)
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose logs temporal-worker --tail 50'

# Follow live
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose logs -f test-nextjs'
```

## Database

Postgres runs in the `yb-pg` container. **App data** for test-nextjs is in database `test_nextjs_payload`, port **5433** inside the container.

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose exec -T yb-pg psql -h localhost -p 5433 -U postgres -d test_nextjs_payload -c "\dt" | head -30'
```

Example queries:

```bash
# Subjects with more than one subject_product (can cause duplicate My Data UI rows)
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose exec -T yb-pg psql -h localhost -p 5433 -U postgres -d test_nextjs_payload -c "
SELECT s.subject_id, s.first_name, s.last_name, COUNT(sp.id) AS sp_count
FROM subjects s
JOIN subject_products sp ON sp.subject_id = s.subject_id
GROUP BY s.subject_id, s.first_name, s.last_name
HAVING COUNT(sp.id) > 1
ORDER BY sp_count DESC
LIMIT 10;
"'
```

| Database | Use |
|----------|-----|
| `test_nextjs_payload` | test-nextjs app tables (subjects, gather, SoW/SoF, etc.) |
| `risk` | risk-calculator (may be empty on this VPS) |
| `postgres` | Default admin DB; list DBs with `\l` |

Do not use `idcl` — that name is in container env but the database may not exist on this host.

## Env diff (local vs VPS)

Non-secret keys only:

```bash
devenv shell -- bash -c '
echo "=== LOCAL ==="
grep -E "^(COMPOSE_FILE|IDCLEAR_APP_HOST|NEXT_PUBLIC_VERIDAS_MOCK|NG_CLIENT_VERIDAS)=" .env 2>/dev/null || true
echo "=== VPS ==="
ssh targ@212.227.30.157 "grep -E \"^(COMPOSE_FILE|IDCLEAR_APP_HOST|NEXT_PUBLIC_VERIDAS_MOCK|NG_CLIENT_VERIDAS)=\" ~/idclear/monorepo/.env 2>/dev/null || true"
'
```

## Internal container checks (on VPS via SSH)

```bash
devenv shell -- ssh targ@212.227.30.157 \
  'cd ~/idclear/monorepo && docker compose exec -T test-nextjs wget -qO- http://127.0.0.1:3000/healthz'
```
