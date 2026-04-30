# Beround Security Hardening — Claude Code Install Script
# Run this in PowerShell as the user (no admin required)
# Usage: iex (iwr "https://raw.githubusercontent.com/Beround-India/beround_marketplace/main/install-beround-security.ps1").Content

$ErrorActionPreference = "Stop"
$MARKETPLACE = "https://github.com/Beround-India/beround_marketplace.git"
$PLUGIN_NAME = "beround-security"
$CLAUDE_DIR  = "$env:USERPROFILE\.claude"
$PLUGIN_DIR  = "$CLAUDE_DIR\plugins\$PLUGIN_NAME"
$CMD_DIR     = "$CLAUDE_DIR\commands"
$SETTINGS    = "$CLAUDE_DIR\settings.json"

Write-Host ""
Write-Host "=== Beround Security Hardening — Installing ===" -ForegroundColor Cyan

# 1. Clone / update plugin files
Write-Host "`n[1/4] Fetching plugin from marketplace..."
if (Test-Path $PLUGIN_DIR) {
    Write-Host "  Plugin dir exists — pulling latest..."
    Push-Location $PLUGIN_DIR
    git pull --quiet
    Pop-Location
} else {
    $TMP = "$env:TEMP\beround_marketplace_install"
    if (Test-Path $TMP) { Remove-Item $TMP -Recurse -Force }
    git clone --quiet --depth 1 $MARKETPLACE $TMP
    New-Item -ItemType Directory -Force -Path $PLUGIN_DIR | Out-Null
    Copy-Item "$TMP\$PLUGIN_NAME\*" $PLUGIN_DIR -Recurse -Force
    Remove-Item $TMP -Recurse -Force
}
Write-Host "  Done." -ForegroundColor Green

# 2. Register slash commands
Write-Host "`n[2/4] Registering slash commands..."
New-Item -ItemType Directory -Force -Path $CMD_DIR | Out-Null
Copy-Item "$PLUGIN_DIR\commands\security-sync.md"     "$CMD_DIR\security-sync.md"     -Force
Copy-Item "$PLUGIN_DIR\commands\security-scan.md"     "$CMD_DIR\security-scan.md"     -Force
Copy-Item "$PLUGIN_DIR\commands\security-research.md" "$CMD_DIR\security-research.md" -Force
Write-Host "  /security-sync, /security-scan, /security-research registered." -ForegroundColor Green

# 3. Update settings.json
Write-Host "`n[3/4] Updating Claude Code settings..."

$hookBase = "$env:USERPROFILE\.claude\plugins\beround-security\hooks".Replace("\", "/")
# Normalise to forward slashes for cross-platform hook paths
$hookBase = "~/.claude/plugins/beround-security/hooks"

if (Test-Path $SETTINGS) {
    $cfg = Get-Content $SETTINGS -Raw | ConvertFrom-Json
} else {
    $cfg = [PSCustomObject]@{}
}

# Correct hook format for Claude Code (PreToolUse / PostToolUse)
$preHooks = @(
    "$hookBase/01-destructive-command-guard.sh",
    "$hookBase/02-package-denylist.sh",
    "$hookBase/03-hallucinated-package-detector.sh",
    "$hookBase/04-data-exfiltration-guard.sh",
    "$hookBase/06-sensitive-file-protection.sh",
    "$hookBase/07-env-var-exfiltration-guard.sh",
    "$hookBase/08-git-safety-guard.sh",
    "$hookBase/09-executable-creation-guard.sh",
    "$hookBase/10-package-policy-enforcer.sh"
)
$postHooks = @("$hookBase/05-mcp-prompt-injection-detector.sh")

$hooksCfg = [PSCustomObject]@{
    PreToolUse  = @($preHooks  | ForEach-Object { [PSCustomObject]@{ matcher = ".*"; hooks = @([PSCustomObject]@{ type = "command"; command = "bash `"$_`"" }) } })
    PostToolUse = @($postHooks | ForEach-Object { [PSCustomObject]@{ matcher = ".*"; hooks = @([PSCustomObject]@{ type = "command"; command = "bash `"$_`"" }) } })
}

# Remove old wrong-format hooks if present
if ($cfg.PSObject.Properties["hooks"]) { $cfg.PSObject.Properties.Remove("hooks") }
if ($cfg.PSObject.Properties["pre_tool_call"]) { $cfg.PSObject.Properties.Remove("pre_tool_call") }
if ($cfg.PSObject.Properties["post_tool_result"]) { $cfg.PSObject.Properties.Remove("post_tool_result") }
$cfg | Add-Member -Force -NotePropertyName "hooks" -NotePropertyValue $hooksCfg

# Marketplace entry
$mktEntry = [PSCustomObject]@{
    "beround-internal-marketplace" = [PSCustomObject]@{
        source = [PSCustomObject]@{ source = "git"; url = $MARKETPLACE }
    }
}
if ($cfg.PSObject.Properties["extraKnownMarketplaces"]) { $cfg.PSObject.Properties.Remove("extraKnownMarketplaces") }
$cfg | Add-Member -Force -NotePropertyName "extraKnownMarketplaces" -NotePropertyValue $mktEntry

$cfg | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS -Encoding utf8
Write-Host "  settings.json updated." -ForegroundColor Green

# 4. Done
Write-Host "`n[4/4] Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart Claude Code"
Write-Host "  2. Run /security-sync  (downloads threat signatures)"
Write-Host "  3. Run /security-scan  (runs all hooks + logs to Notion)"
Write-Host ""
