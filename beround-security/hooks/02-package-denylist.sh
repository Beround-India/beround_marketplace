#!/usr/bin/env bash
# BEROUND SECURITY HOOK 02 — Package Denylist (BLOCK)
# Blocks installation of known-malicious packages.
# Reads from synced signatures; falls back to hardcoded defaults.

TOOL_INPUT="${TOOL_INPUT:-}"
SIG_DIR="${BEROUND_SIGNATURES_DIR:-$HOME/.claude/beround-security/signatures}"
DENYLIST_FILE="$SIG_DIR/package-denylist.json"

if command -v jq &>/dev/null && [ -f "$DENYLIST_FILE" ]; then
  NPM_DENIED=$(jq -r '.npm[]' "$DENYLIST_FILE" 2>/dev/null)
  PIP_DENIED=$(jq -r '.pip[]' "$DENYLIST_FILE" 2>/dev/null)
else
  NPM_DENIED="crossenv cross-env.js d3.js"
  PIP_DENIED="colourama urlib3 urllib"
fi

for pkg in $NPM_DENIED $PIP_DENIED; do
  if echo "$TOOL_INPUT" | grep -qw "$pkg"; then
    echo "BEROUND SECURITY [HOOK 02]: BLOCKED — denied package detected: '$pkg'" >&2
    exit 1
  fi
done
exit 0
