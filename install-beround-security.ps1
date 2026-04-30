# =============================================================================
# Beround Security Hardening - Claude Code Install Script (Windows)
# Installs to ~/.claude/ which is shared by Claude Code CLI, Desktop App,
# and the VS Code extension - one install covers all surfaces.
#
# Usage:
#   git clone https://github.com/Beround-India/beround_marketplace.git "$env:TEMP\bm"
#   & "$env:TEMP\bm\install-beround-security.ps1"
# =============================================================================

$ErrorActionPreference = "Stop"

$MARKETPLACE_URL = "https://github.com/Beround-India/beround_marketplace.git"
$PLUGIN_NAME     = "beround-security"
$CLAUDE_DIR      = "$env:USERPROFILE\.claude"
$PLUGIN_DIR      = "$CLAUDE_DIR\plugins\$PLUGIN_NAME"
$CMD_DIR         = "$CLAUDE_DIR\commands"
$SETTINGS        = "$CLAUDE_DIR\settings.json"
$SIG_DIR         = "$CLAUDE_DIR\beround-security\signatures"

function Write-Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-OK($msg)        { Write-Host "    [OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg)      { Write-Host "    [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg)      { Write-Host "    [FAIL] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   Beround Security Hardening - Claude Code     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   Installs to: $CLAUDE_DIR"
Write-Host "   Works in:    Claude Code CLI / Desktop / VS Code"
Write-Host "================================================" -ForegroundColor Cyan

# =============================================================================
# STEP 1 - Prerequisites
# =============================================================================
Write-Step "1/5" "Checking prerequisites..."

$prereqFail = $false

# Git
try   { $v = git --version 2>&1; Write-OK "git found ($v)" }
catch { Write-Fail "git not found. Install from https://git-scm.com"; $prereqFail = $true }

# Bash (Git Bash - needed for hooks to run)
try   { $v = bash --version 2>&1 | Select-Object -First 1; Write-OK "bash found ($v)" }
catch { Write-Fail "bash not found. Install Git for Windows (includes Git Bash): https://git-scm.com"; $prereqFail = $true }

# Python3 (needed for security-sync)
$python = $null
foreach ($cmd in @("python3", "python")) {
    try {
        $v = & $cmd --version 2>&1
        if ($v -match "Python 3") { $python = $cmd; Write-OK "python found ($v)"; break }
    } catch {}
}
if (-not $python) { Write-Warn "Python 3 not found. /security-sync will not work without it." }

if ($prereqFail) {
    Write-Host "`n  Fix the above issues then re-run this script." -ForegroundColor Red
    exit 1
}

# =============================================================================
# STEP 2 - Clone plugin files
# =============================================================================
Write-Step "2/5" "Installing plugin files..."

$TMP = "$env:TEMP\beround_mkt_$(Get-Random)"
try {
    Write-Host "    Cloning marketplace..." -NoNewline
    git clone --quiet --depth 1 $MARKETPLACE_URL $TMP 2>&1 | Out-Null
    Write-Host " done."

    if (Test-Path $PLUGIN_DIR) {
        Write-Host "    Updating existing install..."
        Remove-Item $PLUGIN_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $PLUGIN_DIR | Out-Null
    Copy-Item "$TMP\$PLUGIN_NAME\*" $PLUGIN_DIR -Recurse -Force
    Write-OK "Plugin installed to $PLUGIN_DIR"
} catch {
    Write-Fail "Failed to clone marketplace: $_"
    Write-Fail "Make sure you have access to github.com/Beround-India/beround_marketplace"
    exit 1
} finally {
    if (Test-Path $TMP) { Remove-Item $TMP -Recurse -Force }
}

# =============================================================================
# STEP 3 - Register slash commands
# =============================================================================
Write-Step "3/5" "Registering slash commands..."

New-Item -ItemType Directory -Force -Path $CMD_DIR | Out-Null

foreach ($cmd in @("security-sync", "security-scan", "security-research")) {
    $src = "$PLUGIN_DIR\commands\$cmd.md"
    if (Test-Path $src) {
        Copy-Item $src "$CMD_DIR\$cmd.md" -Force
        Write-OK "/$cmd"
    } else {
        Write-Warn "/$cmd - source file not found, skipping"
    }
}

# =============================================================================
# STEP 4 - Write Claude Code settings
# =============================================================================
Write-Step "4/5" "Updating Claude Code settings..."

# Load existing settings or start fresh
if (Test-Path $SETTINGS) {
    try   { $cfg = Get-Content $SETTINGS -Raw | ConvertFrom-Json }
    catch { Write-Warn "Could not parse existing settings.json - creating fresh copy."; $cfg = [PSCustomObject]@{} }
} else {
    New-Item -ItemType Directory -Force -Path $CLAUDE_DIR | Out-Null
    $cfg = [PSCustomObject]@{}
}

# Hook paths - forward slashes required by bash on Windows
$hp = "$PLUGIN_DIR".Replace("\", "/")

# PreToolUse: all 9 guard hooks in one matcher
$preHooks = @(
    "01-destructive-command-guard.sh",
    "02-package-denylist.sh",
    "03-hallucinated-package-detector.sh",
    "04-data-exfiltration-guard.sh",
    "06-sensitive-file-protection.sh",
    "07-env-var-exfiltration-guard.sh",
    "08-git-safety-guard.sh",
    "09-executable-creation-guard.sh",
    "10-package-policy-enforcer.sh"
) | ForEach-Object { [PSCustomObject]@{ type = "command"; command = "bash `"$hp/hooks/$_`"" } }

# PostToolUse: MCP prompt injection detector
$postHooks = @(
    [PSCustomObject]@{ type = "command"; command = "bash `"$hp/hooks/05-mcp-prompt-injection-detector.sh`"" }
)

$hooksCfg = [PSCustomObject]@{
    PreToolUse  = @([PSCustomObject]@{ matcher = ".*"; hooks = $preHooks })
    PostToolUse = @([PSCustomObject]@{ matcher = ".*"; hooks = $postHooks })
}

# Remove any old/wrong hook keys before writing
foreach ($key in @("hooks", "pre_tool_call", "post_tool_result")) {
    if ($cfg.PSObject.Properties[$key]) { $cfg.PSObject.Properties.Remove($key) }
}
$cfg | Add-Member -Force -NotePropertyName "hooks" -NotePropertyValue $hooksCfg

# Marketplace registration
$mktCfg = [PSCustomObject]@{
    "beround-internal-marketplace" = [PSCustomObject]@{
        source = [PSCustomObject]@{ source = "git"; url = $MARKETPLACE_URL }
    }
}
if ($cfg.PSObject.Properties["extraKnownMarketplaces"]) { $cfg.PSObject.Properties.Remove("extraKnownMarketplaces") }
$cfg | Add-Member -Force -NotePropertyName "extraKnownMarketplaces" -NotePropertyValue $mktCfg

$cfg | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS -Encoding utf8
Write-OK "Hooks registered (PreToolUse / PostToolUse)"
Write-OK "Marketplace registered"

# =============================================================================
# STEP 5 - First signature sync
# =============================================================================
Write-Step "5/5" "Syncing threat signatures..."

try {
    $ghCfg   = Get-Content "$PLUGIN_DIR\config\github.json" -Raw | ConvertFrom-Json
    $pat     = $ghCfg.pat
    $base    = "https://raw.githubusercontent.com/Beround-India/beround_security/main/claude-security-signatures"
    $headers = @{ Authorization = "token $pat" }

    New-Item -ItemType Directory -Force -Path $SIG_DIR | Out-Null

    $files = @(
        "version.json",
        "signatures/threat-model.json",
        "signatures/package-denylist.json",
        "signatures/mcp-allowed-domains.json",
        "signatures/package-policy.json"
    )
    foreach ($f in $files) {
        $resp = Invoke-WebRequest -Uri "$base/$f" -Headers $headers -UseBasicParsing -ErrorAction Stop
        $dest = "$SIG_DIR\$(Split-Path $f -Leaf)"
        [System.IO.File]::WriteAllBytes($dest, $resp.Content)
    }

    $version = (Get-Content "$SIG_DIR\version.json" -Raw | ConvertFrom-Json).version
    Write-OK "Signatures synced to v$version"
} catch {
    Write-Warn "Could not sync signatures: $_"
    Write-Warn "Run /security-sync manually after restarting Claude Code."
}

# =============================================================================
# DONE
# =============================================================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "   Installation complete!                       " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed to : $CLAUDE_DIR" -ForegroundColor White
Write-Host "  Plugin dir   : $PLUGIN_DIR" -ForegroundColor White
Write-Host "  Commands     : /security-sync, /security-scan, /security-research" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "    1. Restart Claude Code  (or Reload Window in VS Code)" -ForegroundColor White
Write-Host "    2. Type  /security-scan  to run your first scan" -ForegroundColor White
Write-Host ""
