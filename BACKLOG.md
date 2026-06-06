# Backlog

The work queue. `/next-task` takes the first unchecked item in **Current Focus**; when
that's empty it promotes from **Up Next**. Keep items small enough to be one spec each.

## Current Focus

- [ ] **Establish the build + provenance pipeline** — land `.github/workflows/build.yml`
  (operator-applied; guarded path) that builds the image, pushes to
  `ghcr.io/coreyjonoliver-labs/claude-dev`, and attaches a SLSA build-provenance
  attestation; confirm a pushed digest verifies with `gh attestation verify`. Proves the
  spec → review-gate → track loop end to end.

## Up Next

- [ ] **Pin the base image by digest** — add `@sha256:…` to `FROM node:22-bookworm-slim`
  and wire Renovate to keep it current.

## Later

- [ ] Add `hadolint` config (`.hadolint.yaml`) if the default ruleset needs tuning.
- [ ] Revisit `/graduate` if the image ever becomes load-bearing enough to want a CI gate
  + branch protection.
