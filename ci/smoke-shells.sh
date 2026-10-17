#!/bin/bash
# Smoke test, run INSIDE the image by the build workflow (uid 1000, read-only
# rootfs, tmpfs /tmp and home):
#   docker run ... -v "$PWD/ci:/ci:ro" <image> bash /ci/smoke-shells.sh
#
# Seeds the home volume the way a long-lived one can look: the stock Debian
# ~/.profile and ~/.bashrc, plus a decoy `claude` in BOTH home-volume bin dirs
# (~/.local/bin is where Claude Code's native installer puts its binary;
# ~/.npm-global/bin is where `npm i -g` does). Then asserts:
#   1. a non-login shell resolves the baked binary;
#   2. a tmux window (the documented attach path) is a NON-login shell that
#      resolves the baked binary and prints no warning;
#   3. a LOGIN shell in a tmux window IS shadowed (~/.profile prepends
#      ~/.local/bin) and the prompt-time detector WARNS about it.
set -euo pipefail

BAKED=/usr/local/bin/claude
fail() { echo "FAIL: $*" >&2; exit 1; }

test "$(id -u)" = 1000 || fail "not uid 1000"
touch "$HOME/.probe" || fail "home not writable"
if touch /usr/local/bin/.probe 2>/dev/null; then fail "rootfs writable"; fi
test "${DISABLE_AUTOUPDATER-}" = 1 || fail "DISABLE_AUTOUPDATER unset"
test "${DISABLE_UPDATES-}" = 1 || fail "DISABLE_UPDATES unset"

cp /etc/skel/.profile /etc/skel/.bashrc "$HOME/"
for d in .local/bin .npm-global/bin; do
  mkdir -p "$HOME/$d"
  printf '#!/bin/sh\necho shadow\n' > "$HOME/$d/claude"
  chmod +x "$HOME/$d/claude"
done

# 1. Non-login shell.
p="$(type -P claude)"
echo "non-login: claude -> $p"
test "$p" = "$BAKED" || fail "non-login shell resolves $p"
test "$(claude --version)" != shadow || fail "non-login shell runs the decoy"

# Wait until FILE is non-empty (bounded).
wait_for() { for _ in $(seq 100); do [ -s "$1" ] && return 0; sleep 0.1; done; fail "timed out waiting for $1"; }

tmux new-session -d -s smoke -x 200 -y 50
trap 'tmux kill-server 2>/dev/null || true' EXIT

# Typed into a pane: "<login|nonlogin> <path claude resolves to>".
# shellcheck disable=SC2016  # expanded by the pane's shell, not this one
PROBE='echo "$(shopt -q login_shell && echo login || echo nonlogin) $(type -P claude)"'

# 2. A tmux window (with an empty default-command tmux starts a LOGIN shell).
tmux send-keys -t smoke:0 "$PROBE > /tmp/win.txt" Enter
wait_for /tmp/win.txt
echo "tmux window: $(cat /tmp/win.txt)"
test "$(cat /tmp/win.txt)" = "nonlogin $BAKED" || fail "tmux window: $(cat /tmp/win.txt)"
sleep 0.3
if tmux capture-pane -p -t smoke:0 | grep -q 'claude-dev: WARNING'; then
  fail "tmux window printed the shadow warning"
fi

# 3. A login shell: shadowed, and the prompt warns.
tmux new-window -t smoke:1
tmux send-keys -t smoke:1 'exec bash -l' Enter
sleep 0.5
tmux send-keys -t smoke:1 "$PROBE > /tmp/login.txt" Enter
wait_for /tmp/login.txt
echo "login shell: $(cat /tmp/login.txt)"
test "$(cat /tmp/login.txt)" = "login $HOME/.local/bin/claude" \
  || fail "expected the login shell to be shadowed (the detector's case): $(cat /tmp/login.txt)"
sleep 0.3
tmux capture-pane -p -t smoke:1 | grep -q 'claude-dev: WARNING' \
  || fail "login shell is shadowed but no warning was printed"

echo "smoke-shells: PASS"
