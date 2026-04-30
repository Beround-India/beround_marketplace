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
  Windows: ..\\config\\notion.json

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
    "Host Name":          {"rich_text": [{"text": {"content": "<hostname>"}}]},
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
