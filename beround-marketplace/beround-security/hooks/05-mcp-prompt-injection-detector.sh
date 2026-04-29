#!/usr/bin/env bash
# BEROUND SECURITY HOOK 05 — MCP Prompt Injection Detector (BLOCK)
# Detects prompt injection patterns in MCP tool results.

TOOL_RESULT="${TOOL_RESULT:-}"
PATTERNS=(
  "ignore previous instructions"
  "disregard your"
  "new instructions:"
  "system prompt:"
  "you are now"
  "forget everything"
  "override safety"
)

for pat in "${PATTERNS[@]}"; do
  if echo "$TOOL_RESULT" | grep -qiE "$pat"; then
    echo "BEROUND SECURITY [HOOK 05]: BLOCKED — prompt injection pattern in MCP result: '$pat'" >&2
    exit 1
  fi
done
exit 0
