# Link Shortener + Analytics

A self-hosted URL shortener with hit analytics.

The app is deliberately small: two endpoints and a table. The point of this
repo is everything around it — containers, CI/CD, TLS, server hardening, and
recovering the whole stack when it breaks.

This README is written as a case study, not just a setup guide.

---

## Status at a glance

| Area | State |
|---|---|
| App (API + Postgres + web UI) | Done |
| Dockerfiles, multi-stage, non-root | Done |
| docker-compose (app + db + nginx) | Done |
| Image sizes measured and recorded | Done |
| GHCR push (manual dry run) | Done |
| git-SHA tagging | Moved to CI/CD |
| CI/CD pipeline with rollback | Not started |
| Host nginx + TLS (Let's Encrypt) | Not started |
| systemd supervision | Not started |
| Server hardening (SSH, UFW, upgrades) | Not started |
| Monitoring scripts + timers | Not started |
| Docker incident drills (DR1-DR3) | Done |
| Linux incident drills (VPS reboot, disk full) | Not started |

---

## Architecture

Target architecture. Items marked **(pending)** are planned but not built yet.

```
                          Internet
                             |
                             v
                 +--------------------------+
                 |  Host nginx  (pending)   |   :443  TLS (Let's Encrypt)
                 |  reverse proxy           |   :80  -> redirect to :443
                 +--------------------------+
                             |
                             v
                 +--------------------------+
                 |  frontend container      |   nginx (non-root)
                 |  static files + /api     |   :8080
                 +--------------------------+
                    |                  |
             static |                  | /api/*
                    v                  v
                (browser)      +--------------------------+
                               |  backend container       |   Node/Express (non-root)
                               |  /shorten  /:code        |   :3000
                               +--------------------------+
                                           |
                                           v
                               +--------------------------+
                               |  db container            |   Postgres 16
                               |  links table             |   internal only
                               +--------------------------+
                                           |
                                    named volume: pgdata
```

Key facts about the current stack:

- Only the frontend is published to the host (`8080`). The backend and database
  are reachable only inside the Docker network.
- The database stores its data in the named volume `pgdata`, so it survives
  container recreation.
- All services carry healthchecks and `restart: unless-stopped`.

### Request flow (current runtime)

Shorten:
1. Browser posts a URL to `/api/shorten` on the frontend.
2. Frontend nginx proxies `/api/*` to `backend:3000`.
3. Backend inserts a row and returns the short code.

Redirect (`GET /:code`):
1. A request for `/<code>` is not a static file, so nginx forwards it to the backend.
2. The backend updates the hit count and returns a 302 to the target URL.

---

## Repo layout

```
link-shortener/
├── backend/
│   ├── src/index.js         Express API (shorten, redirect, health, list)
│   ├── Dockerfile           multi-stage, runs as `node`
│   ├── .dockerignore
│   └── package.json
├── frontend/
│   ├── src/main.js          form + links table
│   ├── index.html
│   ├── nginx.conf           static serving + /api proxy
│   ├── Dockerfile           Vite build + nginx-unprivileged, runs as `nginx`
│   ├── .dockerignore
│   └── package.json
├── docker-compose.yml       db + backend + frontend
├── .env.example             config template
├── capstone-project-brief.md
└── README.md
```

---

## Tech stack

| Layer | Choice |
|---|---|
| Backend | Node 22, Express 4, `pg` 8 |
| Database | Postgres 16 (alpine) |
| Frontend | Vite 6, plain HTML/JS |
| Web server | nginx (unprivileged image) |
| Packaging | Docker, docker-compose |

---

## Quick start

1. Create your env file and set real secrets:

   ```bash
   cp .env.example .env
   ```

2. Build and start the stack:

   ```bash
   docker compose up -d --build
   ```

3. Open the app at <http://localhost:8080>.

4. Check that everything is healthy:

   ```bash
   docker compose ps
   ```

### Configuration

All configuration is injected from `.env`. It is gitignored. Only
`.env.example` is committed.

| Variable | Purpose |
|---|---|
| `POSTGRES_USER` | database user |
| `POSTGRES_PASSWORD` | database password |
| `POSTGRES_DB` | database name |
| `DATABASE_URL` | full connection string used by the backend |
| `PORT` | backend listen port (3000) |

---

## API reference

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/shorten` | take a URL, return a short code |
| `GET` | `/:code` | redirect and log a hit |
| `GET` | `/health` | DB-backed health check |
| `GET` | `/links` | list all links with hit counts |

Example calls (through the frontend proxy):

```bash
# create a short link
curl -X POST http://localhost:8080/api/shorten \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com"}'

# list links
curl http://localhost:8080/api/links
```

---

## Container images

Measured with `docker image inspect`. Sizes are the values `docker images`
shows (decimal MB).

| Image | Size | Runs as |
|---|---|---|
| `link-shortener-backend:latest` | 244 MB | `node` (non-root) |
| `link-shortener-frontend:latest` | 82.3 MB | `nginx` (non-root) |

Notes:

- The backend is a multi-stage build: dependencies are installed in a build
  stage and only production dependencies and source ship in the final image.
- The frontend is a multi-stage build too: Vite builds the static bundle, then
  a small `nginxinc/nginx-unprivileged` image serves it. The final image is
  almost exactly the size of that base image, because the app adds only a tiny
  static bundle.

---

## Deployment and CI/CD

Not started. Planned pipeline:

GitHub push -> GitHub Actions (lint, test, build) -> push image to GHCR tagged
with the git SHA -> SSH deploy to VPS -> pull image by SHA -> restart compose ->
post-deploy health check -> automatic rollback to the previous good SHA if the
health check fails.

No workflow files exist yet.

## Server operations

Not started. Planned:

- Hardening script: non-root deploy user, key-only SSH, custom SSH port, UFW
  allowing only SSH/80/443, unattended security upgrades.
- systemd unit to run `docker compose up` on boot and on crash.
- Health-check script plus a systemd timer every 5 minutes.
- Disk-usage alert script plus a timer.
- Log rotation for container logs.
- Host nginx as reverse proxy and Let's Encrypt TLS with auto-renewal.

---

## Incident logs

Required breakage tests. Each entry will be filled in as it is run.
**Status: not yet run.**

### Incident 1 — Kill the app container, confirm auto-restart

- Date:
- What I did:
- What happened:
- How I diagnosed it:
- Fix / outcome:
- Takeaway:

### Incident 2 — Reboot the whole VPS, confirm full recovery

- Date:
- What I did:
- What happened:
- How I diagnosed it:
- Fix / outcome:
- Takeaway:

### Incident 3 — Push a broken image, confirm CI/CD catches it or rolls back

- Date:
- What I did:
- What happened:
- How I diagnosed it:
- Fix / outcome:
- Takeaway:

### Incident 4 — Fill the disk, confirm the alert fires, then recover

- Date:
- What I did:
- What happened:
- How I diagnosed it:
- Fix / outcome:
- Takeaway:

---

## Known issues

None open.

- Resolved: short-code paths now reach the backend. Requests that do not match
  a static file fall through to a named `@backend` location in nginx, so
  `GET /<code>` redirects correctly while `/` and `/assets/*` stay static.

---

## Roadmap

- [x] App, database, and web UI
- [x] Dockerfiles (multi-stage, non-root) and compose
- [x] Measure and record image sizes
- [ ] Git repo, branch protection, and CI/CD with rollback
- [x] Manual GHCR push (dry run)
- [ ] git-SHA tagging in CI/CD
- [ ] Host nginx + Let's Encrypt TLS
- [ ] systemd supervision
- [ ] Server hardening script
- [ ] Monitoring scripts and timers
- [x] Run Docker incident drills (DR1-DR3)
- [ ] Write the incident logs in this README
- [ ] Run Linux incident drills (VPS reboot, disk full)
- [x] Fix the short-link redirect
