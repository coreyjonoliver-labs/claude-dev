# claude-dev — Project Intelligence

A minimal, non-root container image for running Claude Code as an interactive
Kubernetes dev pod. Published to `ghcr.io/coreyjonoliver-labs/claude-dev` with SLSA
build provenance.

Claude Code reads this file at the start of every session. It is the map: the settled
decisions and the few rules that govern every change. The detailed conventions —
Dockerfile rules, the documentation checklist, task procedures — live in the
`dockerfile-conventions` skill (`.claude/skills/dockerfile-conventions/SKILL.md`); load
it before implementing or reviewing a change.

## Overview

One artifact: a container image with Claude Code + git + `gh` + tmux baked in, run as a
long-lived attended dev pod you attach to over `kubectl exec` + tmux. Deliberately
minimal — per-repo toolchains are installed interactively in the session and persist on
the pod's home volume, not baked into the image.

## Tech stack

- **Build:** a single `Dockerfile`, `FROM node:22-bookworm-slim` (digest-pinned; Renovate keeps it current).
- **Registry:** GHCR — `ghcr.io/coreyjonoliver-labs/claude-dev` (public package).
- **CI:** GitHub Actions builds, pushes, and attaches a Sigstore-signed SLSA
  build-provenance attestation on every change to `Dockerfile`/`tmux.conf`.

## Architecture decisions

The settled choices. Follow them; don't relitigate them in a change.

1. **Minimal on purpose.** Only Claude Code + git + `gh` + tmux + a few base tools.
   Per-repo/per-language toolchains are installed at runtime in the session, not added
   to the image. New baked-in tooling needs a reason.
2. **Non-root, UID 1000.** Runs as the `claude` user so the image satisfies a
   restrictive (non-root, read-only-rootfs) pod security posture. Don't add `USER root`
   tails or world-writable paths.
3. **tmux config on the rootfs** (`/etc/tmux.conf`, not `~/.tmux.conf`) so a home-volume
   mount can't shadow it.
4. **Reproducible, no startup egress.** Claude Code is `npm install`-ed at build time, not
   on container start. Keep build-time installs pinned and deterministic.
5. **Built + attested by CI; consumers digest-pin.** The image is never built locally for
   release. The digest pin gives immutability; the attestation gives origin. Pushed
   actions are SHA-pinned (Renovate keeps them current).
6. **Specs are the source of truth.** Every non-trivial change is defined by exactly one
   spec in `docs/specs/`.

## Coding standards (the must-knows)

Full detail is in the `dockerfile-conventions` skill. The essentials:

- **`hadolint` clean** on the Dockerfile before review.
- **`docker build` succeeds** from a clean context.
- **Pin everything** — base image by tag (digest where practical), apt/npm installs
  deterministic, GitHub Actions by SHA.
- **Clean up apt layers** (`rm -rf /var/lib/apt/lists/*`) and keep layers lean.
- **No secrets** baked into the image or committed to the repo.

## Operating profile

**Operating profile:** greenfield

A low-ceremony single-image repo. The gate runs locally (guard hooks + a fresh-context
review); no CI gate / branch protection / CODEOWNERS yet. Run `/graduate` if this ever
becomes load-bearing enough to want merge-boundary hardening (the spec-workflow plugin's
greenfield → established profile model).

## Quality gate

A change is **not done** until the review gate passes:

- The **lint** command (`hadolint Dockerfile`) is clean.
- The **build** command (`docker build`) succeeds.

The canonical commands live in `.claude/spec-workflow.json` (`commands.*`), surfaced in
the session-start "Project verification" block. Show command output rather than asserting
success.

## Spec workflow

1. **Spec** — write/update `docs/specs/<name>.md` (`/spec <name>`).
2. **Execute** — `/review-gate <name>` runs implementer → code-reviewer →
   security-auditor (when in scope) → fix loop until zero CRITICAL/HIGH. For a
   one-sentence change, `/implement-and-review`.
3. **Track** — on a green gate: set the spec `Complete`, tick `BACKLOG.md`, append a dated
   `PROGRESS.md` entry.

`/next-task` drives this end to end against the backlog.

## What NOT to do

- Don't implement without a spec for anything non-trivial.
- Don't mark work done without running the gate.
- Don't add baked-in tooling without a stated reason (the image stays minimal).
- Don't unpin a base image, dependency, or action.
- Don't commit secrets.

## Tracking files

- **`BACKLOG.md`** — the queue (Current Focus / Up Next / Later).
- **`PROGRESS.md`** — the dated log of completed work.
