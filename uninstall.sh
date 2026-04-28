#!/usr/bin/env bash
set -euo pipefail

# San Martín Tools — MCP Uninstaller (macOS / Linux)
# Removes everything the installer added and restores your original config.

CLAUDE_DIR="$HOME/.claude"
MARKETPLACE_DIR="$CLAUDE_DIR/local-marketplace"
MARKER="$MARKETPLACE_DIR/.sanmartin-mcp-installed"

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "  $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
echo "San Martín Tools — MCP Uninstaller"
echo "────────────────────────────────────"
echo ""

# ── 1. Check marker — only uninstall what we installed ───────────────────────
if [ ! -f "$MARKER" ]; then
  if [ -d "$MARKETPLACE_DIR" ]; then
    error "$MARKETPLACE_DIR exists but was not created by this installer.\nAborting to avoid data loss."
  else
    warn "San Martín Tools (MCP) does not appear to be installed. Nothing to do."
    exit 0
  fi
fi

# ── 2. Uninstall plugin and remove marketplace registration ───────────────────
info "Uninstalling plugin..."
claude plugin uninstall sanmartin-mcp@local 2>/dev/null \
  && success "Plugin uninstalled" \
  || info "Plugin was not installed — skipping"

info "Removing marketplace registration..."
claude plugin marketplace remove local 2>/dev/null \
  && success "Marketplace registration removed" \
  || info "Marketplace was not registered — skipping"

# ── 3. Remove local-marketplace directory ────────────────────────────────────
info "Removing $MARKETPLACE_DIR..."
rm -rf "$MARKETPLACE_DIR"
success "Removed $MARKETPLACE_DIR"

# ── 4. Restore CLAUDE.md ─────────────────────────────────────────────────────
if [ -f "$CLAUDE_DIR/CLAUDE.md.bak" ]; then
  mv "$CLAUDE_DIR/CLAUDE.md.bak" "$CLAUDE_DIR/CLAUDE.md"
  success "Restored CLAUDE.md from backup"
elif [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  rm "$CLAUDE_DIR/CLAUDE.md"
  success "Removed CLAUDE.md (created by installer, no prior backup)"
fi

# ── 5. Restore settings.json ─────────────────────────────────────────────────
if [ -f "$CLAUDE_DIR/settings.json.bak" ]; then
  mv "$CLAUDE_DIR/settings.json.bak" "$CLAUDE_DIR/settings.json"
  success "Restored settings.json from backup"
elif [ -f "$CLAUDE_DIR/settings.json" ]; then
  rm "$CLAUDE_DIR/settings.json"
  success "Removed settings.json (created by installer, no prior backup)"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}San Martín Tools (MCP) removed successfully.${NC}"
echo ""
echo "  Restart Claude Code to complete the cleanup."
echo ""
