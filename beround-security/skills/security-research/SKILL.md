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
