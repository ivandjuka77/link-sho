# Capstone Project Brief

Combining Linux ops, Docker, and CI/CD, with per-stage requirements checklists.

---

## Project Brief

### What you're building

A **self-hosted "Link Shortener + Analytics" service** — deliberately simple app, deliberately non-trivial infrastructure. The app itself should take you an hour, tops (or reuse one of your existing fullstack apps if it has an API + DB + frontend shape). The entire point of this project is **everything around the app**: how it's hosted, secured, containerised, deployed, and recovered when it breaks.

### App shape (keep it minimal)

**Backend:** API with 2 endpoints — POST /shorten (takes a URL, returns a short code) and GET /:code (redirects + logs a hit). Use whatever language you're comfortable in.

**Database:** Postgres (or SQLite if you want less complexity) — stores the URL mappings and hit counts.

**Frontend:** One page — a form to submit a URL and see the shortened result, plus a simple table of your links with hit counts. This can be barebones HTML/JS.

Don't over-engineer the app. If you spend more than a day on the app itself, you're avoiding the infra work, which is the actual point.

### Target architecture

- GitHub push → GH Actions CI → Build + push image → SSH deploy to VPS
- Nginx (reverse proxy + TLS) → App container → Postgres container
- systemd supervises docker compose on boot + crash

The **deploy user** connects over SSH with a hardened, non-root, key-only account. **UFW** only allows 22 (custom port), 80, and 443. **Nginx** terminates TLS (Let's Encrypt) and reverse-proxies to your app container. **systemd** ensures the whole docker compose stack comes back up after a reboot or crash. **GitHub Actions** builds the image, pushes to GHCR, then SSHes into the VPS to pull and restart — with a health check and automatic rollback if it fails.

### The "break it on purpose" requirement

A project isn't a real test of DevOps skill until you've broken it and fixed it. Before you consider this done, you must: kill the app container and confirm it auto-restarts; reboot the entire VPS and confirm everything comes back without manual intervention; push a broken image on purpose and confirm CI/CD catches it or the rollback kicks in; fill the disk and confirm you can diagnose and recover. Document each of these in your README as "incident logs" — this is genuinely what makes a portfolio project stand out to an interviewer.

### Deliverable

A GitHub repo with: the app code, Dockerfiles, docker-compose.yml, the GitHub Actions workflow, your systemd unit files (checked in, not just on the server), your VPS hardening script from Stage 1, and a README that documents the architecture, setup steps, and your 4 incident logs from the breakage tests above. This README is your interview talking piece — treat it like a mini case study, not just a getting-started guide.

---

## Linux Ops Todo

### Server hardening

- [ ] Fresh Ubuntu 24.04 VPS provisioned
  - Run this from your Stage 1 hardening script, don't do it manually — this is also a test that the script still works
- [ ] Non-root deploy user created with SSH key-only auth
  - Password auth disabled entirely in sshd_config
- [ ] SSH on a custom port, root login disabled
  - AllowUsers restricting to only your deploy user
- [ ] UFW configured: allow only SSH (custom port), 80, 443
  - Default deny incoming, default allow outgoing
- [ ] Unattended security upgrades enabled

### Process supervision

- [ ] systemd unit file that runs `docker compose up` on boot
  - Type=oneshot or forking depending on your compose setup; After=docker.service, network-online.target
- [ ] Restart=on-failure configured with a sane RestartSec
  - Test: kill the compose stack manually, confirm systemd brings it back
- [ ] journalctl can show you compose stack start/stop history
  - Verify with journalctl -u yourservice --since today

### Monitoring & maintenance scripts

- [ ] A health-check bash script (set -euo pipefail) that curls your app and checks the response
  - Should exit non-zero on failure so it can be used elsewhere (cron, CI rollback check)
- [ ] A systemd timer that runs the health check every 5 minutes and logs results
- [ ] A disk usage alert script (df threshold check) as a timer
  - Trigger it artificially by filling disk space and confirm it fires
- [ ] Log rotation configured for your app's logs
  - logrotate config or Docker's own log driver limits — either is fine, just don't let logs grow unbounded

### TLS & reverse proxy

- [ ] Nginx installed on the host (or as a container) as reverse proxy
  - Routes :443 traffic to your app container's internal port
- [ ] Let's Encrypt certificate via certbot, auto-renewal confirmed
  - certbot renew --dry-run should succeed

### Incident drills (required — document each)

- [ ] Reboot the VPS entirely — confirm app is back up with zero manual steps
- [ ] Fill the disk on purpose — confirm your alert fires, then recover
- [ ] Revoke your SSH key on purpose — practice recovering access via your VPS provider's console
  - Every DevOps engineer eventually locks themselves out — know the recovery path

---

## Docker Todo

### Dockerfiles

- [x] Multi-stage Dockerfile for the backend
  - Build stage with full toolchain, final stage copies only the built artifact — final image should be noticeably smaller than a naive single-stage build
- [x] Dockerfile for the frontend (if separate from backend)
  - If using a static frontend, serve via a minimal nginx:alpine stage
- [x] Both images run as a non-root user
  - USER directive — verify with docker exec ... whoami
- [x] .dockerignore configured properly
  - No .git, node_modules, .env, or secrets in the build context
- [x] Image tagged and measured — confirm final size and note it in your README

### Docker Compose

- [x] docker-compose.yml defining app, db, and nginx services
  - Named volumes for Postgres data — must survive container recreation
- [x] Environment variables injected via .env file, never hardcoded
  - .env is in .gitignore — only .env.example is committed
- [x] A custom bridge network connecting the services
  - DB should not be exposed to the host at all — only reachable from the app container
- [x] Healthchecks defined in compose for both app and db services
  - depends_on with condition: service_healthy, not just plain depends_on
- [x] Restart policy set appropriately (unless-stopped)

### Registry & versioning

- [x] Images pushed to GHCR (GitHub Container Registry)
- [ ] Tagging strategy: git SHA + latest, never latest alone — moved to CI/CD (Push stage)
  - [x] Confirm you can pull and run a specific historical version by SHA

### Incident drills (required — document each)

- [x] Kill the app container manually (docker kill) — confirm it restarts automatically
- [x] Delete the DB volume on purpose in a test environment — confirm you understand exactly what data is lost and why
  - Never do this on your real data — spin up a throwaway compose stack for this test
- [x] Deliberately build an image with a broken CMD — confirm the healthcheck catches it before traffic is routed to it

---

## CI/CD Todo

### Pipeline stages

- [ ] Workflow triggers on push to main and on pull_request
  - PRs run lint/test only — never deploy from a PR
- [ ] Lint stage (even basic — eslint, black, whatever fits your stack)
- [ ] Test stage — at minimum, a smoke test hitting your two API endpoints
  - Spin up the app via docker compose inside the CI job itself if possible, not just unit tests
- [ ] Build stage — builds the Docker image using the caching you set up during the CI/CD stage
- [ ] Push stage — pushes to GHCR, tagged with git SHA, only on main

### Deployment job

- [ ] SSH deploy step using an SSH action (e.g. appleboy/ssh-action) or raw ssh in run:
  - SSH private key stored as a GitHub Actions secret, never in code
- [ ] Deploy step pulls the new image by SHA and restarts via docker compose on the VPS
- [ ] Post-deploy health check step — hits your health-check script/endpoint after restart
- [ ] Automatic rollback: if health check fails, redeploy the previous known-good SHA
  - This is the hardest requirement in the whole project — budget real time for it

### Secrets & governance

- [ ] All secrets (SSH key, DB password, VPS host/IP) stored as GitHub Actions secrets
- [ ] Branch protection on main: required status checks (lint+test) before merge
- [ ] No deploy credentials ever appear in logs — verify by checking a run's log output

### Incident drills (required — document each)

- [ ] Push a commit that fails tests — confirm the pipeline stops before deploy and main stays protected
- [ ] Push a commit that passes tests but breaks the app at runtime — confirm your rollback mechanism catches it and reverts
- [ ] Simulate an SSH deploy failure (wrong port temporarily) — confirm the pipeline fails loudly rather than silently succeeding

### Stretch goals (optional)

- [ ] Use OIDC instead of a static SSH key where feasible, or at minimum rotate the deploy key once and document the process
- [ ] Add a Slack or Discord webhook notification on deploy success/failure
- [ ] Blue-green style deploy: run two app containers behind Nginx, switch traffic with zero downtime

---

## Self-Grading

### How to know you're actually done

Don't grade this on "does it work right now." Grade it on whether it **survives the incident drills** in each tab above. A pipeline that deploys successfully once but has no rollback isn't finished — it just hasn't failed yet.

### Weight of each stage in this project

- **30%** — Linux ops — hardening, systemd supervision, monitoring scripts, and surviving a full reboot
- **30%** — Docker — multi-stage builds, compose orchestration, healthchecks, non-root containers
- **40%** — CI/CD — full pipeline including the automatic rollback, which is the hardest and most valuable piece

### The interview test

Once finished, try this: explain the entire request path out loud, from "I push a commit" to "the new version is live," without looking at anything. Then explain what happens at each of the 4 points it could fail, and how you'd know. If you can do this fluently, you're ready to talk about this project in an interview — which is the actual point of building it.
