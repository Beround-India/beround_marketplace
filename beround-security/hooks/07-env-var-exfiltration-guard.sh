#!/usr/bin/env bash
# BEROUND SECURITY HOOK 07 — Env Var Exfiltration Guard (BLOCK)
# Blocks secret env vars being passed to outbound commands.

TOOL_INPUT="${TOOL_INPUT:-}"
SECRET_VARS=("API_KEY" "SECRET" "TOKEN" "PASSWORD" "PASSWD" "PRIVATE_KEY" "AWS_" "AZURE_" "GCP_")

for var in "${SECRET_VARS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qE "\$\{?$var"; then
    if echo "$TOOL_INPUT" | grep -qE "curl|wget|nc |ncat|python.*http|node.*http|fetch"; then
      echo "BEROUND SECURITY [HOOK 07]: BLOCKED — secret env var '${var}' in outbound command" >&2
      exit 1
    fi
  fi
done
exit 0
