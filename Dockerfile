# Session image for running Claude Code as an interactive Kubernetes dev pod.
# Built + attested by this repo's CI and published to
# ghcr.io/coreyjonoliver-labs/claude-dev; consumers digest-pin it. Minimal on
# purpose: Claude Code + git + gh + tmux baked in; per-repo toolchains are
# installed interactively in the session and persist on the pod's home volume.
# Runs as non-root UID 1000 for a Kyverno-restricted (non-root, ro-rootfs) pod.
FROM node:22-bookworm-slim

# Base tools.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git tmux ncurses-term ca-certificates curl jq less openssh-client gnupg \
 && rm -rf /var/lib/apt/lists/*

# System-wide tmux config (true-color; see tmux.conf). On the rootfs at
# /etc/tmux.conf so the /home/claude PVC mount can't shadow it.
COPY tmux.conf /etc/tmux.conf

# GitHub CLI (official apt repo).
RUN mkdir -p -m 755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Claude Code, baked in (reproducible; no startup npm egress).
RUN npm install -g @anthropic-ai/claude-code \
 && npm cache clean --force

# A UID-1000 non-root user whose home is the PVC mount point. The base image's
# `node` user already owns UID 1000, so replace it with `claude`.
RUN userdel -r node 2>/dev/null || true \
 && groupadd -g 1000 claude \
 && useradd -u 1000 -g 1000 -m -d /home/claude -s /bin/bash claude

ENV HOME=/home/claude \
    NPM_CONFIG_PREFIX=/home/claude/.npm-global \
    PATH=/home/claude/.npm-global/bin:$PATH

USER 1000
WORKDIR /home/claude

# The pod stays up via sleep; you attach with `tmux new -A -s main` over kubectl exec.
CMD ["sleep", "infinity"]
