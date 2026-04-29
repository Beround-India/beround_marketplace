# security-sync

## Purpose
Pull the latest threat signatures from GitHub and update the local cache.

## Trigger
`/security-sync`

Also auto-triggered by security-scan if local signatures are older than 24 hours.

## Script

```bash
#!/usr/bin/env bash
set -euo pipefail

GITHUB_BASE="https://raw.githubusercontent.com/Beround-India/beround_security/main"
SIG_DIR="${BEROUND_SIGNATURES_DIR:-$HOME/.claude/beround-security/signatures}"

mkdir -p "$SIG_DIR"

# Fetch remote version.json
REMOTE_VERSION_JSON=$(curl -sf "$GITHUB_BASE/version.json" || true)
if [ -z "$REMOTE_VERSION_JSON" ]; then
  echo "BEROUND SECURITY [SYNC]: WARNING — could not reach GitHub. Using cached signatures." >&2
  exit 0
fi

REMOTE_VER=$(echo "$REMOTE_VERSION_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")

# Compare with local version
LOCAL_VERSION_FILE="$SIG_DIR/version.json"
if [ -f "$LOCAL_VERSION_FILE" ]; then
  LOCAL_VER=$(python3 -c "import json; print(json.load(open('$LOCAL_VERSION_FILE'))['version'])")
  if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
    echo "BEROUND SECURITY [SYNC]: Signatures are up to date (v$REMOTE_VER)."
    exit 0
  fi
fi

# Download all 4 signature files
FILES=(
  "signatures/threat-model.json"
  "signatures/package-denylist.json"
  "signatures/mcp-allowed-domains.json"
  "signatures/package-policy.json"
)

for FILE in "${FILES[@]}"; do
  FILENAME=$(basename "$FILE")
  CONTENT=$(curl -sf "$GITHUB_BASE/$FILE" || true)
  if [ -z "$CONTENT" ]; then
    echo "BEROUND SECURITY [SYNC]: ERROR — failed to fetch $FILENAME. Aborting." >&2
    exit 1
  fi
  echo "$CONTENT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null || {
    echo "BEROUND SECURITY [SYNC]: ERROR — $FILENAME is not valid JSON. Aborting." >&2
    exit 1
  }
  echo "$CONTENT" > "$SIG_DIR/$FILENAME"
done

echo "$REMOTE_VERSION_JSON" > "$LOCAL_VERSION_FILE"
echo "BEROUND SECURITY [SYNC]: Signatures updated to v$REMOTE_VER."
```

## Switching to ADO later
Set `remote_type` to `"ado"` in `settings-template.json`.
The skill will then use `@azure-devops/mcp` instead of curl.
