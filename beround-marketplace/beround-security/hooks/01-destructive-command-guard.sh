#!/usr/bin/env bash
# BEROUND SECURITY HOOK 01 — Destructive Command Guard (BLOCK)
# Blocks shell commands that could delete or overwrite files/system state.

TOOL_INPUT="${TOOL_INPUT:-}"
PATTERNS=(
  "rm -rf"  "rm -fr"  "rm -r /"
  "dd if="  "mkfs"  "shred"
  ":(){:|:&};:"
  "chmod -R 777 /"
  "chown -R"
  "> /dev/"
)

for pat in "${PATTERNS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qiF "$pat"; then
    echo "BEROUND SECURITY [HOOK 01]: BLOCKED — destructive command pattern detected: '$pat'" >&2
    exit 1
  fi
done
exit 0
