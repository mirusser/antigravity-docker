# Antigravity in Docker

Run Google Antigravity and Google Chrome inside Docker, exposed through noVNC in your browser.

This setup:
- mounts a local directory into the container as `/workspace`
- starts Antigravity automatically
- supports Google sign-in inside the container
- uses the official Google Antigravity Linux APT package feed

Current desktop resolution: `2160x1440`

## Requirements

- Docker Engine
- Docker Compose v2
- On Arch Linux, the Docker daemon must be running:

```bash
sudo systemctl enable --now docker.service
```

## Run

From this directory:

```bash
export VNC_PASSWORD='replace-this'
# optional:
# export WORKSPACE_DIR=/absolute/path/to/another/repo

docker compose up -d --build
```

Open:

```text
http://localhost:6080/vnc.html
```

Enter `VNC_PASSWORD` when prompted. Antigravity opens `/workspace`, which defaults to the current directory unless `WORKSPACE_DIR` is set.

Stop it with:

```bash
docker compose down
```

## Configuration

- `VNC_PASSWORD`
  Defaults to `changeme` if not exported.
- `WORKSPACE_DIR`
  Defaults to the current directory and is mounted to `/workspace`.
- Port
  The noVNC UI is published on `6080` in `docker-compose.yml`.
- Resolution
  The VNC desktop size is set in `startup.sh`.

## Important Runtime Settings

Do not remove these unless you want to re-debug Chromium inside Docker:

- `seccomp:unconfined`
  Antigravity's Chromium runtime needs namespace operations blocked by Docker's default seccomp profile.
- `shm_size: 2gb`
  Google auth popups were unreliable with Docker's default `/dev/shm`.
- Chrome wrapper with `--disable-dev-shm-usage`
  Helps keep the Google sign-in popup stable inside the container.
- `dbus-run-session`
  Antigravity is launched inside a session bus so the Google auth browser can render and return cleanly.

## What Is Installed

- Debian Bookworm base image
- TigerVNC + noVNC + Openbox
- Google Chrome from Google's Linux APT repo
- `antigravity` from Google's Artifact Registry APT repo

## Benefits and Drawbacks

### Benefits

- Works on hosts where a native Antigravity setup is inconvenient, including Arch.
- Reproducible environment: same base image, same package sources, same startup flow.
- Easy to reset or update by rebuilding the image.
- Browser-based access through noVNC, with no separate host desktop integration required.
- Keeps most app dependencies inside the container instead of on the host.
- Uses the official Google Antigravity Linux package feed.
- Keeps the mounted workspace separate from the app/runtime environment.

### Drawbacks

- Less native and usually slower than running directly on the host.
- More moving parts: Docker, VNC, noVNC, Chrome, DBus, and container security settings.
- Google sign-in is more fragile in containers than on a normal desktop.
- Hardware acceleration is limited, so GUI responsiveness can be worse.
- Image size and rebuild time are larger than a simple CLI-style container.
- Host integration is weaker for things like clipboard behavior, file dialogs, and notifications.
- This setup relies on `seccomp:unconfined`, so it is less locked down than a default Docker profile.

## Keep Antigravity Up to Date

### 1. Manual update

Preferred approach: rebuild the image without Docker layer cache so the latest `antigravity` package is installed into the image itself.

```bash
docker compose build --no-cache antigravity
docker compose up -d --force-recreate antigravity
```

Verify the installed version:

```bash
docker compose exec antigravity bash -lc 'apt-cache policy antigravity | sed -n "1,20p"'
docker compose exec antigravity bash -lc 'dpkg -s antigravity | sed -n "1,20p"'
```

If you also want the newest Chrome package from Google's repo, use the same no-cache rebuild flow.

### 2. Let Antigravity's agent do it for you

Open this repo in Antigravity and ask the agent to perform the same persistent update flow. This repo includes `AGENTS.md` with repo-specific guidance, so the agent should follow it.

Example prompt:

```text
Update the Antigravity Docker image in this repo to the latest available package version.
Use the persistent image-based approach, not a one-off in-container apt upgrade.
Rebuild with no cache, recreate the container, then verify the installed version with
`apt-cache policy antigravity` and `dpkg -s antigravity`. Show me the final version.
```

The important part is to avoid a temporary update only inside the running container. A one-off `apt-get install antigravity` inside the live container will be lost the next time the container is rebuilt or recreated.

## Verify It Is Official Google Antigravity

Check the configured package source:

```bash
docker compose exec antigravity bash -lc 'cat /etc/apt/sources.list.d/antigravity.list'
```

Expected repo:

```text
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/
```

Check the installed package metadata:

```bash
docker compose exec antigravity bash -lc 'dpkg -s antigravity | sed -n "1,20p"'
```

Expected fields include:

- `Maintainer: Google, LLC`
- `Homepage: https://antigravity.google`

Check the repo signing key:

```bash
docker compose exec antigravity bash -lc 'gpg --show-keys --with-fingerprint /etc/apt/keyrings/antigravity.gpg'
```

Expected signer:

- `Artifact Registry Repository Signer <artifact-registry-repository-signer@google.com>`
- fingerprint `35BA A0B3 3E9E B396 F59C A838 C0BA 5CE6 DC63 15A3`

Google's own download frontend references the same Linux APT key URL and `pkg.dev` project repo used by this image.

## Rebuild After Changes

If you change `Dockerfile`, `startup.sh`, or `docker-compose.yml`:

```bash
docker compose up -d --build
```

## Quick Checks

Verify the noVNC endpoint:

```bash
curl -I http://localhost:6080/vnc.html
```

Check that Antigravity is running:

```bash
docker compose exec antigravity bash -lc 'pgrep -af "antigravity /workspace"'
```
