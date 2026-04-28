# San Martin Tools -- MCP Uninstaller (Windows)
# Removes everything the installer added and restores your original config.
#
# If execution policy blocks this script, run:
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = 'Stop'

$ClaudeDir      = "$env:USERPROFILE\.claude"
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

# -- 1. Check marker -----------------------------------------------------------
if (-not (Test-Path $Marker)) {
    if (Test-Path $MarketplaceDir) {
        Write-Fail "$MarketplaceDir exists but was not created by this installer.`nAborting to avoid data loss."
    } else {
        Write-Warn "San Martin Tools (MCP) does not appear to be installed. Nothing to do."
        exit 0
    }
}

# -- 2. Remove local-marketplace directory -------------------------------------
Write-Info "Removing $MarketplaceDir..."
Remove-Item -Recurse -Force $MarketplaceDir
Write-Success "Removed $MarketplaceDir"

# -- 3. Restore settings.json --------------------------------------------------
$SettingsJson    = "$ClaudeDir\settings.json"
$SettingsJsonBak = "$ClaudeDir\settings.json.bak"

if (Test-Path $SettingsJsonBak) {
    Move-Item -Force $SettingsJsonBak $SettingsJson
    Write-Success "Restored settings.json from backup"
} elseif (Test-Path $SettingsJson) {
    Remove-Item $SettingsJson
    Write-Success "Removed settings.json (created by installer, no prior backup)"
}

# -- Done ----------------------------------------------------------------------
Write-Host ""
Write-Host "San Martin Tools (MCP) removed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "  Restart Claude Code to complete the cleanup."
Write-Host ""
