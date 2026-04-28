# San Martín Tools — MCP Install

Thin client for San Martín Tools — slash commands for Claude Code backed by a remote MCP server. You need a beta API key to use it.

---

## What you get

| Skill | Invoke | Description |
|-------|--------|-------------|
| Spec | `/spec` | Full spec-driven development: plan → TDD implementation → verification |
| Commit | `/commit` | Stages relevant files, generates branch name and commit message from diff, optionally opens a PR |
| PRD | `/prd` | Turns a vague idea into a structured Product Requirements Document |
| Debug prints | `/test-prints` | Adds/removes temporary debug print statements (Python, JS/TS, Go) |

All workflow logic lives on the San Martín Tools MCP server. Without a valid API key the slash commands will fail — there is no offline fallback.

---

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated
- Git configured
- A beta API key (contact the maintainer to get one)

---

## Installation

### macOS / Linux

```bash
# 1. Clone the repo
git clone https://github.com/sirifacu97/san-martin-mcp-install.git

# 2. Run the installer
cd san-martin-mcp-install
./install.sh <your-api-key>

# 3. Restart Claude Code
```

### Windows (PowerShell)

```powershell
# 1. Clone the repo
git clone https://github.com/sirifacu97/san-martin-mcp-install.git

# 2. Run the installer
cd san-martin-mcp-install
.\install.ps1 -ApiKey <your-api-key>

# If execution policy blocks the script:
# powershell -ExecutionPolicy Bypass -File install.ps1 -ApiKey <your-api-key>

# 3. Restart Claude Code
```

After restarting, type `/` in Claude Code — you should see `/commit`, `/prd`, `/spec`, `/test-prints`.

---

## Updating

After the maintainer ships a new version, re-run the installer with your API key:

```bash
# macOS / Linux
git pull && ./install.sh <your-api-key>

# Windows
git pull; .\install.ps1 -ApiKey <your-api-key>
```

Or update only the local plugin (does not refresh the MCP server registration):

```bash
claude plugin update sanmartin-mcp@local
# then restart Claude Code
```

---

## Uninstalling

```bash
# macOS / Linux
./uninstall.sh
```

```powershell
# Windows
.\uninstall.ps1
```

The uninstaller removes the plugin, the marketplace registration, and the installed config files. Your previous `settings.json` is restored from backup if one was created during install.

---

## If you have the beta (local) version installed

The beta and MCP installers share the same `~/.claude/local-marketplace` directory. Uninstall the beta first, then run this installer:

```bash
# From the claude-personal-setup repo
./uninstall.sh

# Then from this repo
./install.sh <your-api-key>
```
