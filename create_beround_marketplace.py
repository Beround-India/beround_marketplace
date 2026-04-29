#!/usr/bin/env python3
"""
Creates the beround-marketplace repo structure.
  beround-marketplace/
  ├── marketplace.json          ← catalog file listing available plugins
  └── beround-security/         ← the actual plugin
      ├── .claude-plugin/
      │   └── plugin.json
      ├── hooks/
      │   └── (all 10 bash hooks)
      ├── skills/
      │   ├── security-sync/
      │   ├── security-scan/
      │   └── security-research/
      └── settings-template.json
"""

import json
from pathlib import Path

BASE = Path("beround-marketplace")
PLUGIN = BASE / "beround-security"


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  created  {path}")


def write_json(path: Path, data):
    write(path, json.dumps(data, indent=2) + "\n")


# ── marketplace.json ──────────────────────────────────────────────────────────

marketplace = {
    "$schema": "https://claude.ai/schemas/marketplace/v1.json",
    "name": "Beround Internal Marketplace",
    "description": "Private plugin catalog for Beround employees. Internal use only.",
    "organization": "Beround",
    "contact": "security@beround.nl",
    "plugins": [
        {
            "id": "beround-security",
            "name": "Beround Security Hardening",
            "version": "0.1.0",
            "description": (
                "Security hardening suite for Claude Code. "
                "Installs 10 protective hooks and sync/scan/research skills. "
                "Required for all Beround Claude Code users."
            ),
            "author": "Beround Security Team",
            "category": "security",
            "tags": ["security", "hooks", "compliance", "internal"],
            "required": True,
            "plugin_path": "beround-security",
            "min_claude_code_version": "1.0.0",
            "platforms": ["darwin", "win32"],
            "install_notes": (
                "Requires Git Bash on Windows. "
                "On first install, /security-sync runs automatically to fetch "
                "latest signatures from GitHub repo claude-security-signatures."
            ),
        }
    ],
}

write_json(BASE / "marketplace.json", marketplace)

# ── beround-security/.claude-plugin/plugin.json ───────────────────────────────

plugin_json = {
    "name": "beround-security",
    "version": "0.1.0",
    "description": "Security hardening suite for Claude Code — Beround internal use only.",
    "author": "Beround Security Team",
    "hooks": [
        {"file": "hooks/01-destructive-command-guard.sh",    "name": "Destructive Command Guard",    "event": "pre_tool_call"},
        {"file": "hooks/02-package-denylist.sh",             "name": "Package Denylist",              "event": "pre_tool_call"},
        {"file": "hooks/03-hallucinated-package-detector.sh","name": "Hallucinated Package Detector", "event": "pre_tool_call"},
        {"file": "hooks/04-data-exfiltration-guard.sh",      "name": "Data Exfiltration Guard",       "event": "pre_tool_call"},
        {"file": "hooks/05-mcp-prompt-injection-detector.sh","name": "MCP Prompt Injection Detector", "event": "post_tool_result"},
        {"file": "hooks/06-sensitive-file-protection.sh",    "name": "Sensitive File Protection",     "event": "pre_tool_call"},
        {"file": "hooks/07-env-var-exfiltration-guard.sh",   "name": "Env Var Exfiltration Guard",    "event": "pre_tool_call"},
        {"file": "hooks/08-git-safety-guard.sh",             "name": "Git Safety Guard",              "event": "pre_tool_call"},
        {"file": "hooks/09-executable-creation-guard.sh",    "name": "Executable Creation Guard",     "event": "pre_tool_call", "action": "warn"},
        {"file": "hooks/10-package-policy-enforcer.sh",      "name": "Package Policy Enforcer",       "event": "pre_tool_call"},
    ],
    "skills": [
        {"directory": "skills/security-sync",     "trigger": "/security-sync"},
        {"directory": "skills/security-scan",     "trigger": "/security-scan"},
        {"directory": "skills/security-research", "trigger": "/security-research"},
    ],
    "settings_template": "settings-template.json",
    "on_install": "skills/security-sync/SKILL.md",
}

write_json(PLUGIN / ".claude-plugin" / "plugin.json", plugin_json)

# ── beround-security/settings-template.json ──────────────────────────────────

settings_template = {
    "beround_security": {
        "signatures_dir": "${HOME}/.claude/beround-security/signatures",
        # remote_type controls where security-sync fetches signatures from.
        # Set to "github" for testing, switch to "ado" when migrating to ADO.
        "remote_type": "github",
        # GitHub settings (active during testing)
        "signatures_github_owner": "YOUR_GITHUB_ORG_OR_USERNAME",
        "signatures_github_repo": "claude-security-signatures",
        "signatures_github_branch": "main",
        # ADO settings (fill in before switching remote_type to "ado")
        "signatures_ado_org": "Beround",
        "signatures_ado_project": "Beround Security",
        "signatures_ado_repo": "claude-security-signatures",
        "auto_sync_if_older_than_hours": 24,
        "scan_on_session_start": True,
        "notify_on_findings": True,
    },
    "hooks": {
        "enabled": True,
    },
}

write_json(PLUGIN / "settings-template.json", settings_template)

# ── hooks/*.sh ────────────────────────────────────────────────────────────────

HOOKS = {
    "01-destructive-command-guard.sh": """\
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
""",

    "02-package-denylist.sh": """\
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
""",

    "03-hallucinated-package-detector.sh": """\
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
""",

    "04-data-exfiltration-guard.sh": """\
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
  DOMAIN=$(echo "$TOOL_INPUT" | grep -oE "https?://[^/\" ]+" | head -1)
  echo "BEROUND SECURITY [HOOK 04]: WARNING — outbound request to '$DOMAIN'. Verify this is intentional." >&2
fi
exit 0
""",

    "05-mcp-prompt-injection-detector.sh": """\
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
""",

    "06-sensitive-file-protection.sh": """\
#!/usr/bin/env bash
# BEROUND SECURITY HOOK 06 — Sensitive File Protection (BLOCK)
# Blocks reads/writes to credential files and private keys.

TOOL_INPUT="${TOOL_INPUT:-}"
SENSITIVE_PATTERNS=(
  "\\.ssh/"  "id_rsa"  "id_ed25519"  "\\.pem"  "\\.p12"  "\\.pfx"
  "\\.env"  "secrets\\."  "credentials\\."
  "~/.aws/credentials"  "~/.aws/config"
  "~/.npmrc"  "~/.pypirc"
  "/etc/passwd"  "/etc/shadow"
  "\\.netrc"
)

for pat in "${SENSITIVE_PATTERNS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qE "$pat"; then
    echo "BEROUND SECURITY [HOOK 06]: BLOCKED — access to sensitive file pattern '$pat'" >&2
    exit 1
  fi
done
exit 0
""",

    "07-env-var-exfiltration-guard.sh": """\
#!/usr/bin/env bash
# BEROUND SECURITY HOOK 07 — Env Var Exfiltration Guard (BLOCK)
# Blocks secret env vars being passed to outbound commands.

TOOL_INPUT="${TOOL_INPUT:-}"
SECRET_VARS=("API_KEY" "SECRET" "TOKEN" "PASSWORD" "PASSWD" "PRIVATE_KEY" "AWS_" "AZURE_" "GCP_")

for var in "${SECRET_VARS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qE "\\$\\{?$var"; then
    if echo "$TOOL_INPUT" | grep -qE "curl|wget|nc |ncat|python.*http|node.*http|fetch"; then
      echo "BEROUND SECURITY [HOOK 07]: BLOCKED — secret env var '${var}' in outbound command" >&2
      exit 1
    fi
  fi
done
exit 0
""",

    "08-git-safety-guard.sh": """\
#!/usr/bin/env bash
# BEROUND SECURITY HOOK 08 — Git Safety Guard (BLOCK)
# Blocks force-push, history rewrite, and other dangerous git operations.

TOOL_INPUT="${TOOL_INPUT:-}"
BLOCKED_PATTERNS=(
  "git push --force"  "git push -f "
  "git rebase -i"
  "git filter-branch"
  "git filter-repo"
  "git commit.*--amend"
  "git reset --hard HEAD~"
)

for pat in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$TOOL_INPUT" | grep -qiF "$pat"; then
    echo "BEROUND SECURITY [HOOK 08]: BLOCKED — dangerous git operation: '$pat'" >&2
    exit 1
  fi
done
exit 0
""",

    "09-executable-creation-guard.sh": """\
#!/usr/bin/env bash
# BEROUND SECURITY HOOK 09 — Executable Creation Guard (WARN ONLY)
# Warns when executable permissions are set on new files.

TOOL_INPUT="${TOOL_INPUT:-}"
if echo "$TOOL_INPUT" | grep -qE "chmod [0-9]*[1357][0-9]* |chmod \\+x|install -m"; then
  echo "BEROUND SECURITY [HOOK 09]: WARNING — executable permission set. Verify this is intentional." >&2
fi
exit 0
""",

    "10-package-policy-enforcer.sh": """\
#!/usr/bin/env bash
# BEROUND SECURITY HOOK 10 — Package Policy Enforcer (WARN/BLOCK)
# Enforces pinned versions and approved registries.

TOOL_INPUT="${TOOL_INPUT:-}"

if echo "$TOOL_INPUT" | grep -qE "npm install [a-zA-Z]|pip install [a-zA-Z]"; then
  if ! echo "$TOOL_INPUT" | grep -qE "@[0-9]+\\.[0-9]+|==[0-9]+\\.[0-9]+|~=[0-9]"; then
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
""",
}

for filename, content in HOOKS.items():
    write(PLUGIN / "hooks" / filename, content)

# ── config/notion.json — admin token baked in, repo is private ───────────────

write(PLUGIN / "config" / "notion.json", json.dumps({
    "_comment": (
        "Admin-managed. Repo is private so this token is safe here. "
        "Do not share this file outside the private GitHub repo."
    ),
    "notion_token":   "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",
    "database_id":    "351b9bfa26b0806a9a57d667cdc6cd49",
    "notion_version": "2022-06-28",
}, indent=2) + "\n")

# ── .gitignore — repo-level (private repo, but good hygiene) ─────────────────

write(BASE / ".gitignore", """\
# OS noise
.DS_Store
Thumbs.db

# Local overrides (if anyone ever adds them)
*.local
""")

# ── skills ────────────────────────────────────────────────────────────────────

write(PLUGIN / "skills" / "security-sync" / "SKILL.md", """\
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
""")

write(PLUGIN / "skills" / "security-scan" / "SKILL.md", """\
# security-scan

## Purpose
Run all 10 security hooks and log metadata to Notion Security Scan Log.

## Trigger
`/security-scan`

## How the token works

The Notion token and database ID are stored in `config/notion.json` inside the plugin.
The repo is private so this is safe. Users do not need to configure anything.

## How it works

Claude Code runs this skill when you trigger `/security-scan`. The skill will:

1. Read NOTION_TOKEN and database_id from `config/notion.json`
2. Detect OS (Mac or Windows) for correct path handling
3. Check if signatures are missing or older than 24h — auto-sync if needed
4. Run all 10 hooks in hooks/ directory, capture exit codes and stderr
5. Classify result: `clean` (all pass) | `warnings` (warnings only) | `findings` (any block)
6. POST the 7 metadata fields to Notion
7. Print summary to user

## Reading config/notion.json

Locate `notion.json` relative to this SKILL.md:
  Mac:     ../config/notion.json  (relative to skills/security-scan/)
  Windows: ..\\\\config\\\\notion.json

Parse it with:
```python
import json, pathlib
config_path = pathlib.Path(__file__).parent.parent.parent / "config" / "notion.json"
config = json.loads(config_path.read_text())
token = config["notion_token"]
database_id = config["database_id"]
```

## OS-aware paths

Mac/Linux:
  SIG_DIR = os.environ.get("BEROUND_SIGNATURES_DIR", os.path.expanduser("~/.claude/beround-security/signatures"))

Windows (Git Bash):
  SIG_DIR = os.environ.get("BEROUND_SIGNATURES_DIR", os.path.expanduser("~/.claude/beround-security/signatures"))
  (same — Git Bash uses Unix-style paths)

Windows (cmd/PowerShell fallback):
  SIG_DIR = os.environ.get("BEROUND_SIGNATURES_DIR", os.path.join(os.environ["USERPROFILE"], ".claude", "beround-security", "signatures"))

## Notion API call

POST https://api.notion.com/v1/pages
Headers:
  Authorization: Bearer {notion_token}
  Content-Type: application/json
  Notion-Version: 2022-06-28

Body:
{
  "parent": {"database_id": "351b9bfa26b0806a9a57d667cdc6cd49"},
  "properties": {
    "User":               {"title":     [{"text": {"content": "<user_email>"}}]},
    "Scan Time/Date":     {"date":      {"start": "<ISO8601_UTC_timestamp>"}},
    "Signatures Version": {"rich_text": [{"text": {"content": "<version>"}}]},
    "Status":             {"select":    {"name": "<clean|warnings|findings>"}},
    "Findings Count":     {"number":    <integer>},
    "Hostname":           {"rich_text": [{"text": {"content": "<hostname>"}}]},
    "Duration (ms)":      {"number":    <integer>}
  }
}

## Values to collect before the POST

- user_email:  `git config --global user.email` — fallback to os.environ.get("USERNAME", "unknown") + "@" + hostname
- timestamp:   datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
- version:     read SIG_DIR/version.json → .version field
- hostname:    socket.gethostname()
- duration:    time.time()*1000 at end minus at start, cast to int

## Hook result classification

For each hook in hooks/0*.sh:
- Run with bash (Mac) or bash via Git Bash (Windows), capture exit code + stderr
- exit code != 0  → finding (BLOCK triggered)
- exit code 0 but stderr contains "WARNING" → warning
- Findings Count = total findings + total warnings
- Status = "findings" if any findings, "warnings" if only warnings, "clean" if neither

## Privacy rules
Log ONLY the 7 fields above.
Never log: finding details, file contents, project names, prompts, or code.
""")

write(PLUGIN / "skills" / "security-research" / "SKILL.md", """\
# security-research

## Purpose
Research the current threat landscape and propose signature updates via a PR
against the beround_security repo. Researchers only.

## Trigger
`/security-research`

## Steps

1. Pull current signatures from GitHub raw URLs (Beround-India/beround_security/main).
2. Research new threats (web search):
   - Typosquatted npm/pip packages reported in the last 7 days
   - New MCP prompt injection techniques
   - New data exfiltration patterns targeting LLM coding assistants
   - CVEs affecting packages in the current denylist
3. Propose changes to relevant signature files.
4. Diff proposed vs current.
   - No diff → print "Signatures are current. No PR needed." and exit silently.
5. If diff:
   a. Clone repo, create branch signatures/research-YYYY-MM-DD
   b. Write updated signature files
   c. Commit and push branch
   d. Open PR to main via gh CLI:
      gh pr create --title "Signature update YYYY-MM-DD — <summary>" --body "<PR body>"
6. Print PR URL.

## PR body template

## Summary
<What threats were found and why signatures were updated>

## Changes
- package-denylist.json: added X packages (sources: ...)
- mcp-allowed-domains.json: ...

## Sources
- <URL 1>
- <URL 2>

## Checklist
- [ ] Sources cited and verified
- [ ] No legitimate packages added to denylist
- [ ] Changes match threat-model categories
- [ ] No obvious false positives
- [ ] CHANGELOG entry is human-readable
""")

# ── Done ──────────────────────────────────────────────────────────────────────

print()
print("✅  beround-marketplace/ created successfully.")
print("   Run: find beround-marketplace -type f | sort")