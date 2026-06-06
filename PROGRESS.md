# claude-dev — Progress Log

A running, dated log of completed work. Append a new entry (newest at the top) each time a
spec reaches `Complete` or a meaningful milestone lands. This is the project's memory
between sessions — `session-start` surfaces the latest entry.

## [2026-06-06] — Build + provenance pipeline verified; repo hardened

- The genesis build (run 27075771045) built, pushed, and attested
  `ghcr.io/coreyjonoliver-labs/claude-dev@sha256:24b0fcc…`; `gh attestation verify`
  passed (public-good Sigstore; signer = this repo's `build.yml@refs/heads/main`).
  Spec `docs/specs/build-provenance-pipeline.md` → Complete.
- Suppressed the non-fatal attest warning with `create-storage-record: false`
  (operator-applied to the guarded `build.yml`; the org-gated artifact-metadata storage
  record isn't needed — the attestation persists via the repo API + registry + Rekor).
- Hardening: base image digest-pinned (`node:22-bookworm-slim@sha256:7af03b14…`);
  `renovate.json` added (`config:recommended`, `pinDigests`, 5-day `minimumReleaseAge`,
  `internalChecksFilter: strict`, `automerge: false`) to keep the base image and action
  SHAs current; `.hadolint.yaml` added with documented ignores so the lint gate is clean.

## [2026-06-06] — Adopted the spec-driven workflow

- Initialized the `spec-workflow` plugin in this repo (greenfield profile).
- Recorded the toolchain in `.claude/spec-workflow.json`: `lint = hadolint Dockerfile`,
  `build = docker build .` (no test/format/typecheck — this repo builds one image).
- Wrote `CLAUDE.md`, the `dockerfile-conventions` skill, and seeded `BACKLOG.md`.
- Added `README.md`, `LICENSE` (MIT), `.dockerignore`; fixed the `Dockerfile` header for
  the standalone repo.
- Operator-applied (guarded paths): `.claude/spec-workflow.json`, `.claude/settings.json`,
  and `.github/workflows/build.yml` (the build + provenance pipeline).
