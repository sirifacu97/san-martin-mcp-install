# San Martín Tools — MCP Uninstaller (Windows)
# Removes everything the installer added and restores your original config.
#
# If execution policy blocks this script, run:
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = 'Stop'

$ClaudeDir      = "$env:APPDATA\Claude"
$MarketplaceDir = "$ClaudeDir\local-marketplace"
$Marker         = "$MarketplaceDir\.sanmartin-mcp-installed"

function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info    { param($msg) Write-Host "     $msg" }
function Write-Warn    { param($msg) Write-Host "[!!] $msg" -ForegroundColor Yellow }
function Write-Fail    { param($msg) Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "San Martin Tools -- MCP Uninstaller" -ForegroundColor Cyan
Write-Host "------------------------------------"
Write-Host ""

# ── 1. Check marker ───────────────────────────────────────────────────────────
if (-not (Test-Path $Marker)) {
    if (Test-Path $MarketplaceDir) {
        Write-Fail "$MarketplaceDir exists but was not created by this installer.`nAborting to avoid data loss."
    } else {
        Write-Warn "San Martín Tools (MCP) does not appear to be installed. Nothing to do."
        exit 0
    }
}

# ── 2. Remove MCP server registration ────────────────────────────────────────
Write-Info "Removing MCP server..."
try {
    claude mcp remove sanmartin --scope user 2>$null
    Write-Success "MCP server removed"
} catch {
    Write-Info "MCP server was not registered — skipping"
}

# ── 3. Uninstall plugin and remove marketplace registration ──────────────────
Write-Info "Uninstalling plugin..."
try {
    claude plugin uninstall sanmartin-mcp@local 2>$null
    Write-Success "Plugin uninstalled"
} catch {
    Write-Info "Plugin was not installed — skipping"
}

Write-Info "Removing marketplace registration..."
try {
    claude plugin marketplace remove local 2>$null
    Write-Success "Marketplace registration removed"
} catch {
    Write-Info "Marketplace was not registered — skipping"
}

# ── 4. Remove local-marketplace directory ────────────────────────────────────
Write-Info "Removing $MarketplaceDir..."
Remove-Item -Recurse -Force $MarketplaceDir
Write-Success "Removed $MarketplaceDir"

# ── 5. Restore CLAUDE.md ─────────────────────────────────────────────────────
$ClaudeMd    = "$ClaudeDir\CLAUDE.md"
$ClaudeMdBak = "$ClaudeDir\CLAUDE.md.bak"

if (Test-Path $ClaudeMdBak) {
    Move-Item -Force $ClaudeMdBak $ClaudeMd
    Write-Success "Restored CLAUDE.md from backup"
} elseif (Test-Path $ClaudeMd) {
    Remove-Item $ClaudeMd
    Write-Success "Removed CLAUDE.md (created by installer, no prior backup)"
}

# ── 6. Restore settings.json ─────────────────────────────────────────────────
$SettingsJson    = "$ClaudeDir\settings.json"
$SettingsJsonBak = "$ClaudeDir\settings.json.bak"

if (Test-Path $SettingsJsonBak) {
    Move-Item -Force $SettingsJsonBak $SettingsJson
    Write-Success "Restored settings.json from backup"
} elseif (Test-Path $SettingsJson) {
    Remove-Item $SettingsJson
    Write-Success "Removed settings.json (created by installer, no prior backup)"
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "San Martín Tools (MCP) removed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "  Restart Claude Code to complete the cleanup."
Write-Host ""
