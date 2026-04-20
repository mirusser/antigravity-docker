# AGENTS.md

## Repository Purpose

This repo builds and runs Google Antigravity inside Docker and exposes the desktop through noVNC in a browser.

The repo is intentionally small. The important behavior lives in:
- `Dockerfile`
- `startup.sh`
- `docker-compose.yml`
- `README.md`

Do not add extra layers, services, or tooling unless the change clearly requires it.

## Current Working Shape

- Base image: Debian Bookworm
- Desktop stack: TigerVNC + noVNC + Openbox
- Browser: Google Chrome from Google's Linux APT repo
- IDE: `antigravity` from Google's Artifact Registry APT repo
- Workspace mount: host path -> `/workspace`
- noVNC URL: `http://localhost:6080/vnc.html`
- Current VNC resolution: `2160x1440`

Antigravity is started automatically by `startup.sh` and should open `/workspace`.

## Important Invariants

Treat these as deliberate fixes, not incidental details:

- Keep `seccomp:unconfined` in `docker-compose.yml` unless you have a verified replacement.
  Antigravity's Chromium runtime failed under Docker's default seccomp profile.
- Keep `shm_size: 2gb`.
  The Google auth popup was unreliable with Docker's default `/dev/shm`.
- Keep the Chrome wrapper in `Dockerfile` using `--disable-dev-shm-usage`.
  This helped stabilize Google sign-in inside the container.
- Keep Antigravity running inside `dbus-run-session` in `startup.sh`.
  The Google auth flow depended on having a DBus session bus.
- Do not swap TigerVNC back to `Xvfb + x11vnc` unless you are intentionally reworking the display stack.

If you change any of the above, re-validate the Google sign-in flow, not just container startup.

## Editing Guidance

- Prefer minimal edits. This is a configuration repo, not an app codebase.
- Keep paths generic and portable.
  Do not add hardcoded local paths like `/home/...`.
- Preserve the use of the official Google Antigravity package source:
  `https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/`
- Preserve the use of Google's Chrome APT repo unless there is a strong reason to change it.
- If changing resolution, update only the VNC geometry in `startup.sh` unless the request says otherwise.
- Keep shell scripts POSIX-ish where reasonable, but `startup.sh` is Bash and may use Bash features.

## Validation Checklist

For nontrivial changes to `Dockerfile`, `startup.sh`, or `docker-compose.yml`, run:

```bash
bash -n startup.sh
docker compose config
docker compose up -d --build
curl -I http://localhost:6080/vnc.html
docker compose exec antigravity bash -lc 'pgrep -af "antigravity /workspace"'
```

If the change touches package sources or authenticity checks, also run:

```bash
docker compose exec antigravity bash -lc 'cat /etc/apt/sources.list.d/antigravity.list'
docker compose exec antigravity bash -lc 'dpkg -s antigravity | sed -n "1,20p"'
docker compose exec antigravity bash -lc 'gpg --show-keys --with-fingerprint /etc/apt/keyrings/antigravity.gpg'
```

Expected Antigravity package signals:
- `Maintainer: Google, LLC`
- `Homepage: https://antigravity.google`
- signer `Artifact Registry Repository Signer <artifact-registry-repository-signer@google.com>`

## Common Tasks

### Keep Antigravity up to date

Preferred approach: rebuild the image without Docker layer cache.

Why:
- `antigravity` is installed during the image build.
- A normal cached rebuild can reuse the old APT-install layer and keep the old version.
- `--no-cache` forces a fresh `apt-get update` and package install from Google's repo.

Use:

```bash
docker compose build --no-cache antigravity
docker compose up -d --force-recreate antigravity
```

Then verify the installed version:

```bash
docker compose exec antigravity bash -lc 'apt-cache policy antigravity | sed -n "1,20p"'
docker compose exec antigravity bash -lc 'dpkg -s antigravity | sed -n "1,20p"'
```

If you also want the newest Chrome package from Google's APT repo, use the same no-cache rebuild flow.

Avoid treating ad-hoc package updates inside a running container as the long-term fix.
If you do a one-off test update inside the running container, mirror the result back into the image workflow by rebuilding afterward.

### Change the mounted workspace

Set:

```bash
export WORKSPACE_DIR=/absolute/path/to/another/repo
```

Then rebuild/restart with Compose.

### Change the VNC password

Set:

```bash
export VNC_PASSWORD='new-password'
```

Then rebuild/restart with Compose.

### Change the desktop resolution

Edit the `tigervncserver ... -geometry ...` value in `startup.sh`, then rebuild and verify the live `Xtigervnc` command inside the container.

## Things To Avoid

- Do not commit local screenshots, logs, or scratch files.
- Do not remove `.gitignore` coverage for local debug artifacts without reason.
- Do not assume the auth flow is fixed if only the main Antigravity window renders.
  Historically, the Google popup was the fragile part.
- Do not replace working runtime settings with "simpler" defaults unless you verify the full browser sign-in flow end-to-end.
