# San Martin Tools -- MCP Installer (Windows)
# Run this from the root of the cloned san-martin-mcp-install repo.
#
# Usage: .\install.ps1 -ApiKey <your-api-key>
#
# If execution policy blocks this script, run:
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey <your-api-key>

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

# -- 1. Validate API key -------------------------------------------------------
if ($ApiKey -notmatch '^[A-Za-z0-9_\-]+$') {
    Write-Fail "API key must contain only letters, digits, underscores, and hyphens."
}

# -- 2. Verify we are in the repo root -----------------------------------------
if (-not (Test-Path ".claude-plugin\marketplace.json")) {
    Write-Fail "Run this script from the root of the cloned san-martin-mcp-install repo."
}

# -- 3. Beta-collision check ---------------------------------------------------
if ((Test-Path $BetaMarker) -and (-not (Test-Path $Marker))) {
    Write-Fail "Beta install detected.`n  Run the beta uninstaller first, then re-run this script."
}

# -- 4. Guard against overwriting unrelated local-marketplace ------------------
if ((Test-Path $MarketplaceDir) -and (-not (Test-Path $Marker))) {
    Write-Fail "$MarketplaceDir already exists and was not created by this installer.`nRemove or rename it manually, then re-run."
}

# -- 5. Ensure ~/.claude exists ------------------------------------------------
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir | Out-Null
    Write-Success "Created $ClaudeDir"
}

# -- 6. Back up existing settings.json ----------------------------------------
Write-Info "Backing up existing config..."

$SettingsJson    = "$ClaudeDir\settings.json"
$SettingsJsonBak = "$ClaudeDir\settings.json.bak"

if ((Test-Path $SettingsJson) -and (-not (Test-Path $SettingsJsonBak))) {
    Copy-Item $SettingsJson $SettingsJsonBak
    Write-Success "Backed up settings.json -> settings.json.bak"
} elseif (Test-Path $SettingsJsonBak) {
    Write-Info "settings.json.bak already exists -- keeping original backup"
}

# -- 7. Copy plugin files into local-marketplace -------------------------------
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

New-Item -ItemType File -Path $Marker -Force | Out-Null
Write-Success "Plugin files copied to $MarketplaceDir"

# -- 8. Write settings.json ----------------------------------------------------
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
  },
  "mcpServers": {
    "sanmartin": {
      "type": "http",
      "url": "$ServerUrl/mcp",
      "headers": {
        "Authorization": "Bearer $ApiKey"
      }
    }
  }
}
"@
[System.IO.File]::WriteAllText($SettingsJson, $Settings, (New-Object System.Text.UTF8Encoding $false))
Write-Success "settings.json written"

# -- 9. Register MCP server via CLI -------------------------------------------
Write-Info "Registering MCP server..."

$ClaudeCandidates = @(
    "$env:USERPROFILE\.local\bin\claude.exe",
    "$env:LOCALAPPDATA\Programs\claude\claude.exe",
    "$env:LOCALAPPDATA\Programs\Claude\claude.exe",
    "$env:LOCALAPPDATA\AnthropicClaude\claude.exe"
)
$ClaudeBin = $null
foreach ($candidate in $ClaudeCandidates) {
    if (Test-Path $candidate) { $ClaudeBin = $candidate; break }
}
if (-not $ClaudeBin) {
    $found = Get-Command "claude" -ErrorAction SilentlyContinue
    if ($found) { $ClaudeBin = $found.Source }
}

if ($ClaudeBin) {
    try {
        & $ClaudeBin mcp remove sanmartin --scope user 2>$null
    } catch {}
    & $ClaudeBin mcp add --transport http --scope user sanmartin "$ServerUrl/mcp" --header "Authorization: Bearer $ApiKey"
    Write-Success "MCP server registered"
} else {
    Write-Warn "claude CLI not found -- MCP server not registered via CLI."
    Write-Warn "Run manually after install:"
    Write-Warn "  claude mcp add --transport http --scope user sanmartin `"$ServerUrl/mcp`" --header `"Authorization: Bearer $ApiKey`""
}

# -- Done ----------------------------------------------------------------------
Write-Host ""
Write-Host "San Martin Tools (MCP) installed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "  Next step: restart Claude Code"
Write-Host "  Then type / to see: /commit  /prd  /spec  /test-prints"
Write-Host ""
