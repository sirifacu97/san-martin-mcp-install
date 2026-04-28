# San Martín Tools — MCP Installer (Windows)
# Run this from the root of the cloned san-martin-mcp-install repo.
#
# Usage: .\install.ps1 -ApiKey <api-key>
#
# If execution policy blocks this script, run:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
# Or invoke directly:
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey <api-key>

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

$ClaudeDir      = "$env:USERPROFILE\.claude"
$MarketplaceDir = "$ClaudeDir\local-marketplace"
$Marker         = "$MarketplaceDir\.sanmartin-mcp-installed"
$BetaMarker     = "$MarketplaceDir\.sanmartin-installed"
$ServerUrl      = "https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app"

function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info    { param($msg) Write-Host "     $msg" }
function Write-Warn    { param($msg) Write-Host "[!!] $msg" -ForegroundColor Yellow }
function Write-Fail    { param($msg) Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "San Martin Tools -- MCP Installer" -ForegroundColor Cyan
Write-Host "----------------------------------"
Write-Host ""

# ── 0. Diagnostics ───────────────────────────────────────────────────────────
Write-Host "[DIAG] USERPROFILE  = $env:USERPROFILE"
Write-Host "[DIAG] APPDATA      = $env:APPDATA"
Write-Host "[DIAG] LOCALAPPDATA = $env:LOCALAPPDATA"
Write-Host "[DIAG] ClaudeDir    = $ClaudeDir"
Write-Host "[DIAG] PWD          = $(Get-Location)"
Write-Host "[DIAG] claude in PATH: $(if (Get-Command claude -ErrorAction SilentlyContinue) { (Get-Command claude).Source } else { 'NOT FOUND' })"
Write-Host "[DIAG] marketplace.json exists: $(Test-Path '.claude-plugin\marketplace.json')"
Write-Host ""

# ── 1. Validate API key ───────────────────────────────────────────────────────
if ($ApiKey -notmatch '^[A-Za-z0-9_\-]+$') {
    Write-Fail "API key must contain only letters, digits, underscores, and hyphens."
}

# ── 2. Verify we are in the repo root ────────────────────────────────────────
if (-not (Test-Path ".claude-plugin\marketplace.json")) {
    Write-Fail "Run this script from the root of the cloned san-martin-mcp-install repo."
}

# ── 3. Pre-flight checks ──────────────────────────────────────────────────────
Write-Info "Checking prerequisites..."

if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
    # Claude Code on Windows may not add itself to PATH automatically.
    # Probe known install locations and patch PATH for this session if found.
    $ClaudeCandidates = @(
        "$env:LOCALAPPDATA\Programs\claude\claude.exe",
        "$env:LOCALAPPDATA\Programs\Claude\claude.exe",
        "$env:LOCALAPPDATA\AnthropicClaude\claude.exe",
        "$env:APPDATA\npm\claude.cmd"
    )
    $ClaudeBin = $null
    foreach ($candidate in $ClaudeCandidates) {
        if (Test-Path $candidate) {
            $ClaudeBin = Split-Path $candidate
            break
        }
    }
    if ($ClaudeBin) {
        $env:PATH = "$ClaudeBin;$env:PATH"
        Write-Info "Added Claude to PATH for this session: $ClaudeBin"
    } else {
        Write-Fail "'claude' CLI not found.`n  Make sure Claude Code is installed: https://claude.ai/code`n  If just installed, open a new PowerShell window and retry.`n  If it still fails, find claude.exe and add its folder to your PATH."
    }
}
Write-Success "claude CLI found"

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Fail "'git' not found. Install git and try again."
}
Write-Success "git found"

# ── 4. Beta-collision check ───────────────────────────────────────────────────
if ((Test-Path $BetaMarker) -and (-not (Test-Path $Marker))) {
    Write-Fail "Beta install detected.`n  Run the beta uninstaller first, then re-run this script.`n  From the claude-personal-setup repo: .\uninstall.ps1"
}

# ── 5. Guard against overwriting unrelated local-marketplace ─────────────────
if ((Test-Path $MarketplaceDir) -and (-not (Test-Path $Marker))) {
    Write-Fail "$MarketplaceDir already exists and was not created by this installer.`nRemove or rename it manually, then re-run."
}

# ── 6. Back up existing config files ─────────────────────────────────────────
Write-Info "Backing up existing config..."

$ClaudeMd        = "$ClaudeDir\CLAUDE.md"
$ClaudeMdBak     = "$ClaudeDir\CLAUDE.md.bak"
$SettingsJson    = "$ClaudeDir\settings.json"
$SettingsJsonBak = "$ClaudeDir\settings.json.bak"

if ((Test-Path $ClaudeMd) -and (-not (Test-Path $ClaudeMdBak))) {
    Copy-Item $ClaudeMd $ClaudeMdBak
    Write-Success "Backed up CLAUDE.md → CLAUDE.md.bak"
} elseif (Test-Path $ClaudeMdBak) {
    Write-Info "CLAUDE.md.bak already exists — keeping original backup"
}

if ((Test-Path $SettingsJson) -and (-not (Test-Path $SettingsJsonBak))) {
    Copy-Item $SettingsJson $SettingsJsonBak
    Write-Success "Backed up settings.json → settings.json.bak"
} elseif (Test-Path $SettingsJsonBak) {
    Write-Info "settings.json.bak already exists — keeping original backup"
}

# ── 7. Copy plugin files into local-marketplace ───────────────────────────────
Write-Info "Copying plugin files..."

if (Test-Path $MarketplaceDir) {
    Remove-Item -Recurse -Force $MarketplaceDir
}
New-Item -ItemType Directory -Path $MarketplaceDir | Out-Null

$Excludes = @('.git', 'docs', 'install.sh', 'install.ps1', 'uninstall.sh',
              'uninstall.ps1', 'README.md', '*.example', '.DS_Store')

Get-ChildItem -Path "." -Force | Where-Object {
    $name = $_.Name
    $excluded = $false
    foreach ($pattern in $Excludes) {
        if ($name -like $pattern) { $excluded = $true; break }
    }
    -not $excluded
} | ForEach-Object {
    if ($_.PSIsContainer) {
        Copy-Item -Recurse -Path $_.FullName -Destination "$MarketplaceDir\$($_.Name)"
    } else {
        Copy-Item -Path $_.FullName -Destination "$MarketplaceDir\$($_.Name)"
    }
}

# Write marker
New-Item -ItemType File -Path $Marker -Force | Out-Null
Write-Success "Plugin files copied to $MarketplaceDir"

# ── 8. Write settings.json ────────────────────────────────────────────────────
Write-Info "Writing settings.json..."

$ActualPath = ($MarketplaceDir -replace '\\', '/')
$Settings = @"
{
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebFetch(domain:*)",
      "WebSearch",
      "Agent",
      "mcp__*__*"
    ]
  },
  "extraKnownMarketplaces": {
    "local": {
      "source": {
        "source": "directory",
        "path": "$ActualPath"
      }
    }
  },
  "enabledPlugins": {
    "sanmartin-mcp@local": true
  }
}
"@
Set-Content -Path $SettingsJson -Value $Settings -Encoding UTF8
Write-Success "settings.json written"

# ── 9. Register MCP server ────────────────────────────────────────────────────
Write-Info "Registering MCP server..."
try { claude mcp remove sanmartin --scope user 2>$null } catch {}
claude mcp add --transport http --scope user sanmartin "$ServerUrl/mcp" --header "Authorization: Bearer $ApiKey"
Write-Success "MCP server registered"

# ── 10. Register marketplace and install plugin ───────────────────────────────
Write-Info "Registering marketplace..."
try {
    claude plugin marketplace add "$MarketplaceDir" --scope user 2>$null
} catch {
    Write-Warn "Marketplace may already be registered — continuing"
}

Write-Info "Installing plugin..."
claude plugin install sanmartin-mcp@local
Write-Success "Plugin installed"

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "San Martín Tools (MCP) installed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "  Next step: restart Claude Code"
Write-Host "  Then type / to see: /commit  /prd  /spec  /test-prints"
Write-Host ""
