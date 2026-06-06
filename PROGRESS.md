# claude-dev — Progress Log

A running, dated log of completed work. Append a new entry (newest at the top) each time a
spec reaches `Complete` or a meaningful milestone lands. This is the project's memory
between sessions — `session-start` surfaces the latest entry.

## [2026-06-06] — Adopted the spec-driven workflow

- Initialized the `spec-workflow` plugin in this repo (greenfield profile).
- Recorded the toolchain in `.claude/spec-workflow.json`: `lint = hadolint Dockerfile`,
  `build = docker build .` (no test/format/typecheck — this repo builds one image).
- Wrote `CLAUDE.md`, the `dockerfile-conventions` skill, and seeded `BACKLOG.md`.
- Added `README.md`, `LICENSE` (MIT), `.dockerignore`; fixed the `Dockerfile` header for
  the standalone repo.
- Operator-applied (guarded paths): `.claude/spec-workflow.json`, `.claude/settings.json`,
  and `.github/workflows/build.yml` (the build + provenance pipeline).
