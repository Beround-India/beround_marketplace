#!/usr/bin/env bash
# BEROUND SECURITY HOOK 10 — Package Policy Enforcer (WARN/BLOCK)
# Enforces pinned versions and approved registries.

TOOL_INPUT="${TOOL_INPUT:-}"

if echo "$TOOL_INPUT" | grep -qE "npm install [a-zA-Z]|pip install [a-zA-Z]"; then
  if ! echo "$TOOL_INPUT" | grep -qE "@[0-9]+\.[0-9]+|==[0-9]+\.[0-9]+|~=[0-9]"; then
    echo "BEROUND SECURITY [HOOK 10]: WARNING — package install without pinned version. Pin versions in production." >&2
  fi
fi

UNOFFICIAL_PATTERNS=("--registry http://" "index-url http://" "--extra-index-url" "jfrog" "nexus" "artifactory")
for pat in "${UNOFFICIAL_PATTERNS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qiF "$pat"; then
    echo "BEROUND SECURITY [HOOK 10]: WARNING — unofficial registry detected: '$pat'. Verify this is approved." >&2
  fi
done
exit 0
