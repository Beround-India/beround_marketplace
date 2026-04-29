#!/usr/bin/env bash
# BEROUND SECURITY HOOK 09 — Executable Creation Guard (WARN ONLY)
# Warns when executable permissions are set on new files.

TOOL_INPUT="${TOOL_INPUT:-}"
if echo "$TOOL_INPUT" | grep -qE "chmod [0-9]*[1357][0-9]* |chmod \+x|install -m"; then
  echo "BEROUND SECURITY [HOOK 09]: WARNING — executable permission set. Verify this is intentional." >&2
fi
exit 0
