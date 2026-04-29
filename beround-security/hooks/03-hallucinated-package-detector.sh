#!/usr/bin/env bash
# BEROUND SECURITY HOOK 03 — Hallucinated Package Detector (BLOCK)
# Verifies npm/pip packages exist in the real registry before allowing install.

TOOL_INPUT="${TOOL_INPUT:-}"

check_npm() {
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://registry.npmjs.org/$1")
  [ "$status" = "200" ]
}

check_pip() {
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "https://pypi.org/pypi/$1/json")
  [ "$status" = "200" ]
}

if echo "$TOOL_INPUT" | grep -qE "npm install|npm i "; then
  PKG=$(echo "$TOOL_INPUT" | grep -oE "(npm install|npm i) ([a-zA-Z0-9@/_.-]+)" | awk '{print $NF}')
  if [ -n "$PKG" ] && ! check_npm "$PKG"; then
    echo "BEROUND SECURITY [HOOK 03]: BLOCKED — npm package '$PKG' not found in registry (possible hallucination)" >&2
    exit 1
  fi
fi

if echo "$TOOL_INPUT" | grep -qE "pip install"; then
  PKG=$(echo "$TOOL_INPUT" | grep -oE "pip install ([a-zA-Z0-9_.-]+)" | awk '{print $NF}')
  if [ -n "$PKG" ] && ! check_pip "$PKG"; then
    echo "BEROUND SECURITY [HOOK 03]: BLOCKED — pip package '$PKG' not found in PyPI (possible hallucination)" >&2
    exit 1
  fi
fi
exit 0
