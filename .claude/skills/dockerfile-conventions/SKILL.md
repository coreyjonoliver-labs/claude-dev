---
name: dockerfile-conventions
description: >-
  Detailed conventions for claude-dev — Dockerfile rules (pinning, non-root,
  lean layers, apt/npm hygiene), the build + provenance pipeline, hadolint
  expectations, the documentation-maintenance checklist, and step-by-step task
  procedures. Load this before implementing or reviewing any change to the image.
user-invocable: false
---

# claude-dev — Conventions

The high-level map — overview, architecture decisions, the quality gate, the spec
workflow — lives in `CLAUDE.md`. **This skill is the manual:** the detailed rules the
implementer applies and the reviewer checks against.

## Verification commands

The gate every change must clear, defined in `.claude/spec-workflow.json` (`commands.*`)
and surfaced at session start:

- **Lint** — `hadolint Dockerfile` must be clean (no warnings).
- **Build** — `docker build .` must succeed from a clean context.

There is no test/format/typecheck command — this repo builds one image; the build itself
plus hadolint is the gate.

## Dockerfile rules

- **Pin the base image by digest.** `FROM node:22-bookworm-slim@sha256:…` — always pinned;
  Renovate (`renovate.json`, `pinDigests`) keeps the digest current.
- **Run as non-root.** The image must end on `USER 1000` (the `claude` user). Never leave
  the final user as root; never `chmod` world-writable paths into the image.
- **Lean, deterministic layers.** Combine related `RUN` steps; always
  `rm -rf /var/lib/apt/lists/*` after `apt-get install`; use
  `--no-install-recommends`; `npm cache clean --force` after global installs.
- **No build-time secrets.** No tokens, keys, or `.env` content in layers or build args.
- **Keep it minimal.** Adding a package or tool requires a one-line justification in the
  change's spec — the image's value is its small, predictable surface.
- **Don't break the home-volume contract.** Config that must survive a home-volume mount
  belongs on the rootfs (e.g. `/etc/tmux.conf`), not under `/home/claude`.

## Build + provenance pipeline

- The image is built and pushed **only by CI** (`.github/workflows/build.yml`), never
  built locally for release.
- Every pushed digest gets a Sigstore-signed **SLSA build-provenance** attestation via
  `actions/attest-build-provenance` (keyless, GitHub Actions OIDC). The repo is public, so
  this is anchored to the public-good Sigstore trust root.
- **All GitHub Actions are SHA-pinned** with a `# vX` comment; Renovate keeps them current.
- Verify a published digest:
  `gh attestation verify oci://ghcr.io/coreyjonoliver-labs/claude-dev@sha256:<digest> --repo coreyjonoliver-labs/claude-dev`.

## Security

- The repo carries no secrets; the image carries no secrets. The only credentials touched
  are CI's ambient `GITHUB_TOKEN` (GHCR push) and the OIDC token (keyless signing) — both
  workflow-scoped, never committed.
- Treat any new install source (apt repo, npm registry, fetched URL) as a supply-chain
  surface: pin it, fetch over HTTPS, verify signatures/keys where the upstream provides
  them (as the `gh` apt keyring step already does).

## Documentation-maintenance checklist

When a change alters behavior, update in the same change:

- `README.md` — what's in the image, usage, the verify command.
- `CLAUDE.md` — only if an architecture decision changes (keep it lean).
- This skill — if a convention changes.

## Common task procedures

- **Bump the base image / a dependency:** update the pin, `hadolint Dockerfile`,
  `docker build .`, confirm the image still runs `claude --version` as UID 1000.
- **Bump Claude Code:** change `ARG CLAUDE_CODE_VERSION` (Renovate opens these PRs via the
  `# renovate:` annotation, after the 5-day release-age cooldown). Read the upstream
  changelog for the skipped versions first. Install scripts must stay enabled (the
  postinstall places the native binary); the build fails if `claude --version` does not
  match the pin. Keep `DISABLE_AUTOUPDATER`/`DISABLE_UPDATES` set and the home-volume npm
  bin dir last on `PATH`.
- **Add a baked-in tool:** justify it in the spec, add it to a combined `RUN` with proper
  cleanup, re-lint + re-build, update `README.md`'s "What's in it".
