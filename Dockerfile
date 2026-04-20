FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Display stack and lightweight desktop
RUN apt-get update && apt-get install -y --no-install-recommends \
    openbox \
    x11-xserver-utils \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    wget \
    curl \
    gpg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Google Chrome (required by Antigravity's browser subagent)
RUN mkdir -p /etc/apt/keyrings && \
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable \
    && mv /opt/google/chrome/chrome /opt/google/chrome/chrome.real \
    && printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      '' \
      '# Route Chrome away from /dev/shm for auth popups. The default Docker' \
      '# shared-memory mount is small enough to cause flaky rendering and' \
      '# crashes when Antigravity and Chrome are both active.' \
      'exec -a "$0" /opt/google/chrome/chrome.real \' \
      '  --disable-dev-shm-usage \' \
      '  "$@"' \
      > /opt/google/chrome/chrome \
    && chmod 755 /opt/google/chrome/chrome \
    && rm -rf /var/lib/apt/lists/*

# Google Antigravity
RUN wget -q -O - https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    gpg --dearmor -o /etc/apt/keyrings/antigravity.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
    > /etc/apt/sources.list.d/antigravity.list && \
    apt-get update && apt-get install -y antigravity \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -ms /bin/bash devuser
USER devuser
WORKDIR /home/devuser

COPY --chown=devuser:devuser startup.sh /home/devuser/startup.sh
RUN chmod +x /home/devuser/startup.sh

EXPOSE 6080

CMD ["/home/devuser/startup.sh"]
