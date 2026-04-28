#!/usr/bin/env bash
set -euo pipefail

# San Martín Tools — MCP Installer (macOS / Linux)
# Run this from the cloned repo root.
#
# Usage: ./install.sh <api-key>

CLAUDE_DIR="$HOME/.claude"
MARKETPLACE_DIR="$CLAUDE_DIR/local-marketplace"
MARKER="$MARKETPLACE_DIR/.sanmartin-mcp-installed"
BETA_MARKER="$MARKETPLACE_DIR/.sanmartin-installed"
SERVER_URL="https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app"

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "  $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "San Martín Tools — MCP Installer"
echo "──────────────────────────────────"
echo ""

# ── 1. Validate API key argument ──────────────────────────────────────────────
API_KEY="${1:-}"

if [ -z "$API_KEY" ]; then
  error "Usage: ./install.sh <api-key>"
fi

if ! [[ "$API_KEY" =~ ^[A-Za-z0-9_-]+$ ]]; then
  error "API key must contain only letters, digits, underscores, and hyphens."
fi

# ── 2. Verify we are in the repo root ────────────────────────────────────────
if [ ! -f ".claude-plugin/marketplace.json" ]; then
  error "Run this script from the root of the cloned san-martin-mcp-install repo."
fi

# ── 3. Beta-collision check ───────────────────────────────────────────────────
if [ -f "$BETA_MARKER" ] && [ ! -f "$MARKER" ]; then
  error "Beta install detected.\n  Run the beta uninstaller first, then re-run this script.\n  From the claude-personal-setup repo: ./uninstall.sh"
fi

# ── 4. Guard against overwriting unrelated local-marketplace ─────────────────
if [ -d "$MARKETPLACE_DIR" ] && [ ! -f "$MARKER" ]; then
  error "$MARKETPLACE_DIR already exists and was not created by this installer.\nRemove or rename it manually, then re-run."
fi

# ── 5. Ensure ~/.claude exists ────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR"

# ── 6. Back up existing settings.json ────────────────────────────────────────
info "Backing up existing config..."

if [ -f "$CLAUDE_DIR/settings.json" ] && [ ! -f "$CLAUDE_DIR/settings.json.bak" ]; then
  cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
  success "Backed up settings.json → settings.json.bak"
elif [ -f "$CLAUDE_DIR/settings.json.bak" ]; then
  info "settings.json.bak already exists — keeping original backup"
fi

# ── 7. Copy plugin files into local-marketplace ───────────────────────────────
info "Copying plugin files..."

rm -rf "$MARKETPLACE_DIR"
mkdir -p "$MARKETPLACE_DIR"
touch "$MARKER"

rsync_excludes=(
  --exclude='.git'
  --exclude='.git/'
  --exclude='docs/'
  --exclude='install.sh'
  --exclude='install.ps1'
  --exclude='uninstall.sh'
  --exclude='uninstall.ps1'
  --exclude='README.md'
  --exclude='*.example'
  --exclude='.DS_Store'
)

if command -v rsync &>/dev/null; then
  rsync -a "${rsync_excludes[@]}" . "$MARKETPLACE_DIR/"
else
  cp -R . "$MARKETPLACE_DIR/"
  rm -rf "$MARKETPLACE_DIR/.git" "$MARKETPLACE_DIR/docs"
  rm -f  "$MARKETPLACE_DIR/install.sh" "$MARKETPLACE_DIR/install.ps1"
  rm -f  "$MARKETPLACE_DIR/uninstall.sh" "$MARKETPLACE_DIR/uninstall.ps1"
  rm -f  "$MARKETPLACE_DIR/README.md"
  find "$MARKETPLACE_DIR" -maxdepth 1 -name '*.example' -delete
fi
success "Plugin files copied to $MARKETPLACE_DIR"

# ── 8. Write settings.json ────────────────────────────────────────────────────
info "Writing settings.json..."

cat > "$CLAUDE_DIR/settings.json" <<EOF
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
        "path": "$HOME/.claude/local-marketplace"
      }
    }
  },
  "enabledPlugins": {
    "sanmartin-mcp@local": true
  },
  "mcpServers": {
    "sanmartin": {
      "type": "http",
      "url": "$SERVER_URL/mcp",
      "headers": {
        "Authorization": "Bearer $API_KEY"
      }
    }
  }
}
EOF

success "settings.json written"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}San Martín Tools (MCP) installed successfully.${NC}"
echo ""
echo "  Next step: restart Claude Code"
echo "  Then type / to see: /commit  /prd  /spec  /test-prints"
echo ""
