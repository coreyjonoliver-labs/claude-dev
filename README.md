# claude-dev

A minimal, non-root container image for running [Claude Code](https://docs.claude.com/en/docs/claude-code)
as a long-lived **interactive dev pod** in Kubernetes. Published to
`ghcr.io/coreyjonoliver-labs/claude-dev` with [SLSA build provenance](#provenance).

## What's in it

Built `FROM node:22-bookworm-slim`:

- **Claude Code** (`@anthropic-ai/claude-code`), baked in at an **exact version**
  (`ARG CLAUDE_CODE_VERSION` in the `Dockerfile`) — no startup `npm` egress. Renovate
  proposes bumps after a 5-day release-age cooldown; they are merged by hand.
  - The in-app updater is off (`DISABLE_AUTOUPDATER=1`), and so are manual
    `claude update` / `claude install` (`DISABLE_UPDATES=1`): a self-updated binary
    would sit outside the build attestation. To update, bump the pin.
  - `/home/claude/.npm-global/bin` (where `npm i -g` installs, on the home volume) is
    **last** on `PATH`, so a `claude` installed there can never shadow the baked one.
- **git**, **GitHub CLI** (`gh`), **tmux** (with a true-color `/etc/tmux.conf`)
- `curl`, `jq`, `less`, `gnupg`, `openssh-client`, `ca-certificates`, `ncurses-term`
- Runs as **non-root UID 1000** (`claude`), home at `/home/claude` — fits a
  *restricted* / non-root, read-only-rootfs pod security posture
- `CMD ["sleep", "infinity"]` — the pod stays up; you attach over `kubectl exec` with
  `tmux new -A -s main`

**Minimal on purpose.** Per-repo toolchains (language runtimes, linters, etc.) are
installed interactively inside the session and persist on the pod's home volume — they
are not baked into the image.

## Usage

The image is pulled by a Kubernetes workload that scales a session on demand and
attaches a terminal to it. Consumers should **pin by digest**, not tag:

```yaml
image: ghcr.io/coreyjonoliver-labs/claude-dev@sha256:<digest>
```

The package is public, so no pull credential is required.

## Provenance

Every pushed digest carries a Sigstore-signed **SLSA build-provenance** attestation
produced by this repo's build workflow (`actions/attest-build-provenance`, keyless via
GitHub Actions OIDC). Verify any digest:

```bash
gh attestation verify \
  oci://ghcr.io/coreyjonoliver-labs/claude-dev@sha256:<digest> \
  --repo coreyjonoliver-labs/claude-dev
```

It reports the signer identity as this repo's build workflow on `main`. The attestation
proves *origin* (this CI built these bytes); pin the digest where you use it for *immutability*.

## Building

The build workflow first builds the image into the runner and **smoke-tests** it the way
a pod runs it (UID 1000, read-only rootfs, writable `/tmp` and home): `claude --version`
is exactly the pinned version, `claude --help` lists `--bg` and `agents`, the binary
carries `remote-control --spawn`/`--capacity`, and `claude` resolves to the baked path
even with a decoy `claude` on the home volume. Pull requests stop there.

On `main` (a push touching `Dockerfile`/`tmux.conf`/the workflow, or a manual
`workflow_dispatch`) it then pushes the tested image as
`ghcr.io/coreyjonoliver-labs/claude-dev:0.2.0`, checks the pushed image ID equals the
tested one, and attests the **registry digest** returned by the push. The tag is a
human-readable label only; pin the digest. Action versions are SHA-pinned and kept
current by Renovate.

## License

[MIT](LICENSE)
