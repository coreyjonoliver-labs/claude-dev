# Session image for running Claude Code as an interactive Kubernetes dev pod.
# Built + attested by this repo's CI and published to
# ghcr.io/coreyjonoliver-labs/claude-dev; consumers digest-pin it. Minimal on
# purpose: Claude Code + git + gh + tmux baked in; per-repo toolchains are
# installed interactively in the session and persist on the pod's home volume.
# Runs as non-root UID 1000 to fit a restricted (non-root, read-only-rootfs) pod posture.
FROM node:22-bookworm-slim@sha256:7af03b14a13c8cdd38e45058fd957bf00a72bbe17feac43b1c15a689c029c732

# Base tools.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git tmux ncurses-term ca-certificates curl jq less openssh-client gnupg \
 && rm -rf /var/lib/apt/lists/*

# System-wide tmux config (true-color, non-login window shells; see tmux.conf).
# On the rootfs at /etc/tmux.conf so the /home/claude PVC mount can't shadow it.
COPY tmux.conf /etc/tmux.conf

# Interactive shells warn once if `claude` stops resolving to the baked binary
# (see claude-path-check.bash; a detector: the home volume's startup files run later).
COPY claude-path-check.bash /tmp/claude-path-check.bash
RUN cat /tmp/claude-path-check.bash >> /etc/bash.bashrc \
 && rm /tmp/claude-path-check.bash

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

# Claude Code, baked in at an exact version (reproducible builds; no startup npm
# egress). Renovate proposes bumps via the annotation below, subject to the
# repo's release-age cooldown. Install scripts stay ON: the package's postinstall
# copies the platform-native binary (from its optionalDependencies) over a
# placeholder stub, and without it `claude` is not runnable. The build fails if
# the installed binary does not report exactly the pinned version.
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.296
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
 && npm cache clean --force \
 && v="$(claude --version)" \
 && case "$v" in "${CLAUDE_CODE_VERSION} "*) ;; *) echo "claude --version: '$v', want ${CLAUDE_CODE_VERSION}" >&2; exit 1 ;; esac

# A UID-1000 non-root user whose home is the PVC mount point. The base image's
# `node` user already owns UID 1000, so replace it with `claude`.
RUN userdel -r node 2>/dev/null || true \
 && groupadd -g 1000 claude \
 && useradd -u 1000 -g 1000 -m -d /home/claude -s /bin/bash claude

# - The user's npm global prefix lives on the home volume so tools installed in
#   the session persist, but it goes LAST on PATH, so a `claude` installed there
#   by `npm i -g` does not shadow the pinned one in a non-login shell or a tmux
#   window (/etc/tmux.conf starts windows non-login). NOT guaranteed: a LOGIN shell
#   (`bash -l`) sources ~/.profile from the home volume, whose stock Debian
#   copy prepends ~/.local/bin, and any startup file there can rewrite PATH;
#   /etc/bash.bashrc then WARNS at the prompt.
# - The in-app updater is disabled (DISABLE_AUTOUPDATER), and so are manual
#   `claude update` / `claude install` (DISABLE_UPDATES): a self-updated binary
#   would sit outside the build attestation. Update by bumping the pin.
ENV HOME=/home/claude \
    NPM_CONFIG_PREFIX=/home/claude/.npm-global \
    PATH=$PATH:/home/claude/.npm-global/bin \
    DISABLE_AUTOUPDATER=1 \
    DISABLE_UPDATES=1

USER 1000
WORKDIR /home/claude

# The pod stays up via sleep; you attach with `tmux new -A -s main` over kubectl exec.
CMD ["sleep", "infinity"]
