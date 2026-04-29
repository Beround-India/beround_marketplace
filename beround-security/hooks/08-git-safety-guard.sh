#!/usr/bin/env bash
# BEROUND SECURITY HOOK 08 — Git Safety Guard (BLOCK)
# Blocks force-push, history rewrite, and other dangerous git operations.

TOOL_INPUT="${TOOL_INPUT:-}"
BLOCKED_PATTERNS=(
  "git push --force"  "git push -f "
  "git rebase -i"
  "git filter-branch"
  "git filter-repo"
  "git commit.*--amend"
  "git reset --hard HEAD~"
)

for pat in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qiF "$pat"; then
    echo "BEROUND SECURITY [HOOK 08]: BLOCKED — dangerous git operation: '$pat'" >&2
    exit 1
  fi
done
exit 0
