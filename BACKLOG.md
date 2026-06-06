# Backlog

The work queue. `/next-task` takes the first unchecked item in **Current Focus**; when
that's empty it promotes from **Up Next**. Keep items small enough to be one spec each.

## Current Focus

- [x] **Establish the build + provenance pipeline** — 2026-06-06. `.github/workflows/build.yml`
  builds, pushes, and attests `ghcr.io/coreyjonoliver-labs/claude-dev`; the genesis build
  verified end-to-end with `gh attestation verify` (public-good Sigstore). Spec
  `docs/specs/build-provenance-pipeline.md` Complete.

## Up Next

- [x] **Pin the base image by digest** — 2026-06-06. `FROM node:22-bookworm-slim@sha256:7af03b14…`
  pinned; `renovate.json` added (`pinDigests`, 5-day `minimumReleaseAge`) to keep the base
  image and action SHAs current.

## Later

- [x] Add `hadolint` config (`.hadolint.yaml`) — 2026-06-06. Documented ignores
  (DL3008/DL3016/SC2174) so the lint gate is clean for a current-tools image.
- [ ] Revisit `/graduate` if the image ever becomes load-bearing enough to want a CI gate
  + branch protection.
