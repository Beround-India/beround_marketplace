#!/usr/bin/env bash
# BEROUND SECURITY HOOK 04 — Data Exfiltration Guard (BLOCK)
# Blocks always-blocked domains; warns on unknown outbound requests.

TOOL_INPUT="${TOOL_INPUT:-}"
ALWAYS_BLOCKED=("ngrok.io" "requestbin.com" "webhook.site" "pipedream.net" "burpcollaborator.net")

for domain in "${ALWAYS_BLOCKED[@]}"; do
  if echo "$TOOL_INPUT" | grep -qi "$domain"; then
    echo "BEROUND SECURITY [HOOK 04]: BLOCKED — always-blocked domain detected: '$domain'" >&2
    exit 1
  fi
done

if echo "$TOOL_INPUT" | grep -qE "https?://"; then
  DOMAIN=$(echo "$TOOL_INPUT" | grep -oE "https?://[^/" ]+" | head -1)
  echo "BEROUND SECURITY [HOOK 04]: WARNING — outbound request to '$DOMAIN'. Verify this is intentional." >&2
fi
exit 0
