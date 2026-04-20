#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${HOME}/.vnc"
touch "${HOME}/.Xauthority"
echo "${VNC_PASSWORD:-changeme}" | vncpasswd -f > "${HOME}/.vnc/passwd"
chmod 600 "${HOME}/.vnc/passwd"

cat > "${HOME}/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r "${HOME}/.Xresources" ] && xrdb "${HOME}/.Xresources"
exec openbox
EOF
chmod +x "${HOME}/.vnc/xstartup"

# TigerVNC already provides the X server. Running Xvfb on the same display
# would conflict with it.
tigervncserver :1 -geometry 2160x1440 -depth 24 -localhost no
export DISPLAY=:1

# Give Xvnc a moment to accept clients before starting the UI stack on top.
sleep 2
websockify --web /usr/share/novnc 6080 localhost:5901 &
websockify_pid=$!

# Keep a DBus session alive for the full Antigravity lifetime. The Google
# auth popup appears to rely on a session bus that is not present in the
# minimal container session by default.
dbus-run-session -- bash -lc '
  set -euo pipefail

  antigravity /workspace &
  launcher_pid=$!

  cleanup() {
    kill "${launcher_pid:-}" "${antigravity_pid:-}" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  sleep 5
  antigravity_pid="$(pgrep -o -u "$(id -u)" -f "^/usr/share/antigravity/antigravity /workspace$" || true)"

  if [[ -z "${antigravity_pid}" ]]; then
    wait "${launcher_pid}" || true
    exit 1
  fi

  while kill -0 "${antigravity_pid}" 2>/dev/null; do
    sleep 5
  done
' &
dbus_session_pid=$!

cleanup() {
  kill "${dbus_session_pid:-}" "${websockify_pid:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

while kill -0 "${dbus_session_pid}" 2>/dev/null && kill -0 "${websockify_pid}" 2>/dev/null; do
  sleep 5
done
