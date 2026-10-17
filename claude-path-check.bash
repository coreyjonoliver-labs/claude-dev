
# claude-dev: appended to /etc/bash.bashrc by the Dockerfile.
# A DETECTOR, not a fence: shell startup files on the home volume (~/.profile,
# ~/.bashrc) run after this file and can change PATH. At each prompt, warn once
# per shell if `claude` no longer resolves to the baked, pinned binary.
__claude_dev_baked=/usr/local/bin/claude
__claude_dev_path_check() {
  [ -n "${__claude_dev_warned-}" ] && return 0
  local p
  p="$(type -P claude 2>/dev/null || true)"
  if [ "$p" != "$__claude_dev_baked" ]; then
    __claude_dev_warned=1
    printf 'claude-dev: WARNING: `claude` resolves to %s, not the baked %s.\n' \
      "${p:-nothing}" "$__claude_dev_baked" >&2
    printf 'claude-dev: a binary on the home volume is shadowing the pinned build; remove it or run %s.\n' \
      "$__claude_dev_baked" >&2
  fi
}
PROMPT_COMMAND="__claude_dev_path_check${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
