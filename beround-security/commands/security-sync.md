# security-sync

## Purpose
Pull the latest threat signatures from Azure DevOps and update the local cache.

## Trigger
`/security-sync`

Also auto-triggered by security-scan if local signatures are older than 24 hours.

## ADO Details
- Organization: Beround
- Project: Agentic Engineering Security Scanner
- Repository: Agentic Engineering Security Signatures
- Branch: main
- No PAT required - access via @azure-devops/mcp (pre-configured for all Beround users)

## Steps

1. Use the ADO MCP to fetch `version.json` from the repo root
2. Compare with local version at SIG_DIR/version.json
3. If versions match: print "BEROUND SECURITY [SYNC]: Signatures are up to date (vX.X.X)." and stop
4. If different or missing locally: fetch all 4 signature files via ADO MCP:
   - signatures/threat-model.json
   - signatures/package-denylist.json
   - signatures/mcp-allowed-domains.json
   - signatures/package-policy.json
5. Validate each file is valid JSON
6. Write all files + version.json to SIG_DIR
7. Print "BEROUND SECURITY [SYNC]: Signatures updated to vX.X.X."

## SIG_DIR path

```python
import os, pathlib
if os.name == 'nt':
    SIG_DIR = pathlib.Path(os.environ["USERPROFILE"]) / ".claude" / "beround-security" / "signatures"
else:
    SIG_DIR = pathlib.Path.home() / ".claude" / "beround-security" / "signatures"
SIG_DIR.mkdir(parents=True, exist_ok=True)
```

## ADO MCP usage

Use the available ADO MCP tools (mcp__azure_devops or @azure-devops/mcp) to read files.
Parameters for each file fetch:
- organization: "Beround"
- project: "Agentic Engineering Security Scanner"
- repository: "Agentic Engineering Security Signatures"
- branch/ref: "main"
- path: "/version.json" (or "/signatures/threat-model.json" etc.)

Write each file's content to SIG_DIR using Python:

```python
import json, pathlib

# After fetching content via MCP, write to disk:
(SIG_DIR / "version.json").write_text(version_content, encoding="utf-8")
(SIG_DIR / "threat-model.json").write_text(threat_model_content, encoding="utf-8")
(SIG_DIR / "package-denylist.json").write_text(denylist_content, encoding="utf-8")
(SIG_DIR / "mcp-allowed-domains.json").write_text(domains_content, encoding="utf-8")
(SIG_DIR / "package-policy.json").write_text(policy_content, encoding="utf-8")

version = json.loads(version_content)["version"]
print(f"BEROUND SECURITY [SYNC]: Signatures updated to v{version}.")
```
