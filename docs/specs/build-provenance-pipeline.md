# Spec: Build + provenance pipeline

**Status:** Complete
**Kind:** Implementation
**Author:** Corey Oliver
**Date:** 2026-06-06
**Depends on:** None

---

> **Verified (2026-06-06):** the genesis build (run 27075771045) built, pushed, and
> attested `ghcr.io/coreyjonoliver-labs/claude-dev@sha256:24b0fcc…`; `gh attestation
> verify --repo coreyjonoliver-labs/claude-dev` passed, naming the signer identity
> `…/claude-dev/.github/workflows/build.yml@refs/heads/main` (issuer
> `token.actions.githubusercontent.com`, public-good Sigstore). All acceptance criteria
> met. The org-gated artifact-metadata "storage record" was a non-fatal warning,
> suppressed with `create-storage-record: false` (operator-applied to the guarded
> `build.yml` on the close branch). Hardening alongside the close: base image
> digest-pinned + Renovate configured to keep the base image / action SHAs current, and a
> `.hadolint.yaml` so the lint gate is clean.

## Summary

Stand up this repo's CI so every change to the image builds, pushes to
`ghcr.io/coreyjonoliver-labs/claude-dev`, and attaches a Sigstore-signed SLSA
build-provenance attestation — and a published digest is independently verifiable. This
is the repo's reason to exist and the first run of the spec → review-gate → track loop.

## Goal

- **Implementation:** As the image's maintainer, I want every pushed digest to carry
  verifiable proof that *this repo's CI* built it, so the image's origin is verifiable —
  not just its immutability via the digest pin.

## Background

The image (`Dockerfile` + `tmux.conf`) is published as the public package
`ghcr.io/coreyjonoliver-labs/claude-dev` and digest-pinned where it's used. A digest pin
proves the bytes don't change; it proves nothing about *who built them*. Build provenance
closes that gap.

This repo is **public**, so the attestation is free and anchored to the **public-good
Sigstore** trust root (Fulcio/Rekor) — the standard, well-supported path. This spec is
self-contained: its scope ends at "a verifiable attestation exists for each pushed
digest."

`.github/workflows/**` is operator-edit-only under the guard chain, so the workflow file
is delivered as an operator-applied artifact (the agent provides its exact content); the
`Dockerfile`/`tmux.conf` and docs are normal gated code.

## Requirements

1. The image **shall** run as non-root (UID 1000) and pass `hadolint Dockerfile` with no
   warnings and `docker build .` from a clean context (the repo's quality gate).
2. When a change lands on `main` touching `Dockerfile`, `tmux.conf`, or the build
   workflow (or on manual `workflow_dispatch`), CI **shall** build and push
   `ghcr.io/coreyjonoliver-labs/claude-dev` and attach a `https://slsa.dev/provenance/v1`
   attestation to the pushed **digest** via `actions/attest-build-provenance`
   (keyless GitHub Actions OIDC, `push-to-registry: true`).
3. The workflow **shall** grant exactly the permissions the attestation needs —
   `id-token: write`, `attestations: write`, `packages: write`, `contents: read` — and
   **shall** SHA-pin every action (with a `# vN` comment), Renovate-maintained.
4. A published digest **shall** be verifiable with
   `gh attestation verify oci://ghcr.io/coreyjonoliver-labs/claude-dev@sha256:<digest>
   --repo coreyjonoliver-labs/claude-dev`, reporting this repo's `build` workflow on
   `main` as the signer identity.
5. No secret **shall** be baked into the image or committed to the repo; the only
   credentials used are CI's ambient `GITHUB_TOKEN` (GHCR push) and the OIDC token
   (keyless signing), both workflow-scoped.

## Acceptance Criteria

```gherkin
Given a clean checkout
When I run `hadolint Dockerfile` and `docker build .`
Then hadolint reports no warnings and the build succeeds, producing a non-root (UID 1000) image
```

```gherkin
Given the build workflow is installed and a change to Dockerfile lands on main
When CI runs
Then it pushes ghcr.io/coreyjonoliver-labs/claude-dev and the attest step succeeds
     (the public repo's attestation persists to the public-good Sigstore)
```

```gherkin
Given a digest pushed by the workflow
When I run `gh attestation verify oci://ghcr.io/coreyjonoliver-labs/claude-dev@sha256:<digest> --repo coreyjonoliver-labs/claude-dev`
Then it reports the attestation valid and names this repo's build workflow as signer
```

```gherkin
Given the workflow file
When it is reviewed
Then every action is SHA-pinned and the permissions are exactly id-token/attestations/packages/contents — no broader grant
```

## Interfaces & Files

| File | Change | Notes |
|---|---|---|
| `.github/workflows/build.yml` | **operator-applied** | build + push + attest; SHA-pinned actions; the guard chain forbids agent writes to `.github/workflows/**`, so the agent supplies the verbatim content and the operator commits it |
| `Dockerfile` | (exists) | non-root UID 1000, minimal, lint-clean |
| `tmux.conf` | (exists) | rootfs tmux config |
| `README.md` | (exists) | the `gh attestation verify` command + usage |
| `.claude/skills/dockerfile-conventions/SKILL.md` | (exists) | the build + provenance conventions |

## Data / State Impact

| Entity / Store | Change | Details |
|---|---|---|
| GHCR package `claude-dev` | create/update | new digests + their attestation artifacts; public package |

## Quality & Security Checklist

| Item | Applies? | How this spec satisfies it |
|---|---|---|
| Lint/build gate passes | Yes | Req 1 — hadolint + docker build |
| No secrets in repo/image | Yes | Req 5 — only workflow-scoped GITHUB_TOKEN + OIDC |
| New dependencies justified and pinned | Yes | Req 3 — actions SHA-pinned, base image pinned (Renovate) |
| Least privilege | Yes | Req 3 — exactly the four needed permissions |
| Supply-chain integrity | Yes | the whole point — provenance attestation per digest |
| Public interfaces documented | Yes | README verify command + usage |

## Edge Cases

1. **Pre-existing package, no repo write grant** → first push 403s; the package's Actions
   access must include this repo with Write (operator prereq, noted in README/PROGRESS).
2. **`workflow_dispatch` on a commit lacking the attest step** → no attestation produced;
   only builds from a commit that includes the attest step are attestable.
3. **A second builder pushing the same tag** (a legacy workflow elsewhere) → retire it so
   two workflows don't race the `:0.1.0` tag.

## Testing Strategy

- **Local:** `hadolint Dockerfile`; `docker build .`; run the image and confirm
  `whoami` = `claude` / UID 1000 and `claude --version` works.
- **CI:** a real push builds, pushes, and attests; the run's final line prints the digest.
- **Verification:** `gh attestation verify … --repo coreyjonoliver-labs/claude-dev` passes.
- **Boundary:** the spec guarantees a verifiable attestation exists for each pushed
  digest — that is the entirety of this repo's responsibility.

## Out of Scope

- **SBOM attestation** — a natural fast-follow on the same `attest` machinery; not here.
- **Multi-arch builds** — single-arch for now.

## End-to-End Verification

```bash
hadolint Dockerfile && docker build .              # gate is green
# push to main (or workflow_dispatch) → CI builds, pushes, attests
gh attestation verify \
  oci://ghcr.io/coreyjonoliver-labs/claude-dev@sha256:<digest> \
  --repo coreyjonoliver-labs/claude-dev            # → valid; signer = this repo's build workflow
```

Done = the gate is green, a push yields an attested digest, and `gh attestation verify`
confirms origin against this repo — with no secret in the repo or image.

## Open Questions

- None.
