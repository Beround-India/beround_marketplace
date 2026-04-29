#!/usr/bin/env bash
# BEROUND SECURITY HOOK 06 — Sensitive File Protection (BLOCK)
# Blocks reads/writes to credential files and private keys.

TOOL_INPUT="${TOOL_INPUT:-}"
SENSITIVE_PATTERNS=(
  "\.ssh/"  "id_rsa"  "id_ed25519"  "\.pem"  "\.p12"  "\.pfx"
  "\.env"  "secrets\."  "credentials\."
  "~/.aws/credentials"  "~/.aws/config"
  "~/.npmrc"  "~/.pypirc"
  "/etc/passwd"  "/etc/shadow"
  "\.netrc"
)

for pat in "${SENSITIVE_PATTERNS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qE "$pat"; then
    echo "BEROUND SECURITY [HOOK 06]: BLOCKED — access to sensitive file pattern '$pat'" >&2
    exit 1
  fi
done
exit 0
