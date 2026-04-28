# San Martín MCP Install Implementation Plan

Created: 2026-04-28
Status: VERIFIED
Approved: Yes
Iterations: 0
Worktree: No
Type: Feature

## Summary

**Goal:** Build the public `san-martin-mcp-install` repo — a thin client distribution containing 4 SKILL.md stubs (`/spec`, `/commit`, `/prd`, `/test-prints`) and cross-platform install/uninstall scripts. Each stub instructs Claude to call `mcp__sanmartin__get_phase('<name>')` on the San Martín Tools MCP server. The install script accepts a beta API key, writes the stubs as a plugin under `~/.claude/local-marketplace/`, and configures `~/.claude/settings.json` with the MCP server registration.

**Architecture:** Plugin-marketplace structure mirroring `claude-personal-setup`. The repo ships a `.claude-plugin/marketplace.json` and a `plugins/sanmartin-mcp/` tree containing the 4 stubs. The install scripts copy the marketplace into the user's Claude config dir, write a fresh `settings.json` with the API key + Cloud Run URL inlined, register the marketplace, and install the plugin via `claude plugin install`. Uninstall is symmetric — it removes everything the installer added and restores `.bak` files.

**Tech Stack:** Bash (macOS/Linux), PowerShell (Windows), JSON config, MCP-over-SSE protocol.

## Scope

### In Scope

- `.claude-plugin/marketplace.json` registering the local marketplace
- `plugins/sanmartin-mcp/.claude-plugin/plugin.json` defining the plugin
- 4 SKILL.md stubs: `spec`, `commit`, `prd`, `test-prints` — each ~15-25 lines, frontmatter mirrors the beta repo, body is a 1-instruction call to `mcp__sanmartin__get_phase`
- `settings.json.example` template with `extraKnownMarketplaces`, `enabledPlugins`, and `mcpServers.sanmartin` entries
- `install.sh` — macOS/Linux installer accepting API key as positional arg
- `install.ps1` — Windows installer (mirror of install.sh)
- `uninstall.sh` and `uninstall.ps1` — symmetric uninstallers
- `README.md` — end-user install instructions
- Marker file convention: `.sanmartin-mcp-installed` to distinguish from the beta's `.sanmartin-installed`
- Pre-flight check that refuses to install if the beta marker (`.sanmartin-installed`) is present, with a clear message telling the user to run the beta uninstaller first
- API key validation: must match `^[A-Za-z0-9_\-]+$` so the install script can safely inline it via heredoc/here-string

### Out of Scope

- The MCP server itself (lives in the private `san-martin-mcp` repo per PRD)
- Stubs for sub-skills (`spec-plan`, `spec-implement`, etc.) — sub-skill chaining happens via `get_phase()` calls embedded in returned instructions, no local stubs needed (PRD)
- CLAUDE.md handling — the MCP version is server-driven, the user's CLAUDE.md is left untouched
- Per-user API key management — single shared beta key
- CI/CD, PRs, releases — repo is hand-published for the beta
- E2E browser tests — this is a CLI install tool, no browser surface

## Approach

**Chosen:** Plugin marketplace structure + heredoc-based JSON write for settings.json.

**Why:** Plugin structure matches the beta convention so the cognitive model stays the same across both repos. Heredoc avoids `sed` escaping pain on user-provided strings (URL is hardcoded; only the API key is dynamic, and we validate it to a safe character set).

**Alternatives considered:**
- *Direct user skills (`~/.claude/skills/`)*: simpler but diverges from the beta repo and skips the plugin lifecycle (`claude plugin update`, `claude plugin uninstall`)
- *`sed` substitution into `settings.json.example`*: requires escaping for `/`, `&`, and other sed-special chars in the API key
- *`jq`-based JSON write*: cleaner but adds a `jq` dependency

## Context for Implementer

- **Reference implementation:** `/Users/sirifacu/Developer/claude-personal-setup/install.sh:1-143` and `install.ps1:1-144`. Same step structure, log format, color helpers, and error handling — copy faithfully and adapt the substantive sections.
- **Reference uninstall:** `/Users/sirifacu/Developer/claude-personal-setup/uninstall.sh:1-73` and `uninstall.ps1:1-85`. Same pattern: marker check → plugin uninstall → marketplace remove → directory delete → restore backups.
- **Reference plugin structure:** `/Users/sirifacu/Developer/claude-personal-setup/.claude-plugin/marketplace.json` and `plugins/personal-tools/.claude-plugin/plugin.json`.
- **Reference SKILL.md frontmatter (preserve exactly):**
  - `spec` → `model: opus` (per `/Users/sirifacu/Developer/claude-personal-setup/plugins/personal-tools/skills/spec/SKILL.md:1-8`, but we elevate to opus since the dispatcher in the beta uses sonnet only because Opus runs the planning sub-skills it dispatches to; in the MCP version the server returns the planning text directly so the dispatcher itself benefits from opus). Final choice: keep `model: sonnet` to match the beta dispatcher exactly — the server can still recommend escalation to opus inside returned text.
  - `commit` → `model: sonnet`, `effort: low`
  - `prd` → `model: opus`
  - `test-prints` → `model: sonnet`, `effort: low`
- **MCP tool reference inside stubs:** `mcp__sanmartin__get_phase` (server name `sanmartin` + tool name `get_phase`).
- **Phase-name mapping** (PRD line 81): user-facing slash → phase string passed to `get_phase`:
  - `/spec` → `"spec"`
  - `/commit` → `"commit"`
  - `/prd` → `"prd"`
  - `/test-prints` → `"test_prints"` (underscore — note PRD uses underscore here while spec sub-phases use hyphens)
- **MCP server URL (hardcoded in scripts):** `https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app`
- **MCP transport:** `"type": "sse"` per PRD line 113 ("MCP over HTTP with SSE transport").
- **Auth header:** `"X-API-Key": "<key>"` — single header, plain text, scoped to the user's `~/.claude/settings.json` (file perms inherit user-only).
- **Claude config paths:**
  - macOS/Linux: `$HOME/.claude/`
  - Windows: `$env:APPDATA\Claude\`
- **Backup convention:** `.bak` suffix alongside originals (e.g. `~/.claude/CLAUDE.md.bak`). Restore on uninstall, delete if no backup existed (matches beta `uninstall.sh:50-65`).
- **Marker file (NEW for MCP):** `~/.claude/local-marketplace/.sanmartin-mcp-installed` — distinct from beta's `.sanmartin-installed` so an MCP uninstaller never deletes a beta install.
- **Cross-installer collision detection:** if `~/.claude/local-marketplace/.sanmartin-installed` exists, the MCP installer must abort with: "Beta install detected. Run the beta uninstaller first: `cd <beta-repo> && ./uninstall.sh`".
- **API key validation regex:** `^[A-Za-z0-9_\-]+$`. If invalid: print error, exit non-zero. This guarantees safe heredoc injection without escaping.
- **Plugin install command:** `claude plugin install sanmartin-mcp@local` (matches the marketplace name `local` and plugin name `sanmartin-mcp`).
- **No CLAUDE.md.example** — the install script must NOT touch `~/.claude/CLAUDE.md`. Backup is still created defensively (in case Claude Code touches it during install) but no file is written by us.

## Runtime Environment

N/A — this is a static repo with shell scripts. No service to start, no port, no health check.

## Assumptions

- Claude Code's `mcpServers` schema supports `{ "type": "sse", "url": "...", "headers": { "X-API-Key": "..." } }` per Anthropic's MCP-over-HTTP/SSE docs. Supported by Tasks 4-5 (settings.json template); if the schema differs we'll update the template before the first beta tester runs the script.
- The Cloud Run URL `https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app` is the canonical production endpoint for the beta. Used by Task 4 (install.sh) and Task 5 (install.ps1).
- `claude` CLI is on the user's `PATH` after installing Claude Code — same prerequisite as the beta installer.
- `python3` is available on macOS/Linux for any optional JSON manipulation. (Not strictly required — the heredoc approach avoids it.)
- Beta API keys conform to `^[A-Za-z0-9_\-]+$`. If keys ever contain other characters, Task 4/5 validation needs to widen and we switch to a Python-based JSON writer.
- Testers will run install/uninstall from the freshly-cloned repo root — the script's first action validates this via presence of `.claude-plugin/marketplace.json` (matches beta `install.sh:24`).

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| MCP `"type": "sse"` schema name differs in Claude Code's runtime | Medium | High (server unreachable) | Verify against Claude Code docs during Task 4 implementation; if wrong, update template before any beta tester runs the script |
| User has both beta and MCP installed simultaneously | Medium | Medium (install collision) | Pre-flight check on cross-marker detection (`.sanmartin-installed` blocks MCP install) |
| User runs MCP uninstaller after running beta installer (or vice versa) | Low | High (deletes wrong install) | Each uninstaller checks for its own marker (`.sanmartin-mcp-installed`); aborts if missing |
| API key contains characters that break heredoc | Low | High (corrupted settings.json) | Strict regex validation (`^[A-Za-z0-9_\-]+$`) before any file write |
| Existing `mcpServers` entries in user's settings.json get clobbered by overwrite | Medium | Medium (user loses other MCP servers) | Same approach as beta: back up to `.bak` before overwrite; uninstall restores. Document in README |
| `claude plugin install` fails after marketplace registration | Low | Medium (partial install) | Match beta error handling — `error` and exit; user re-runs after fixing |

## Goal Verification

### Truths

1. After `./install.sh <api-key>`, the file `~/.claude/local-marketplace/plugins/sanmartin-mcp/skills/spec/SKILL.md` exists and contains the literal string `mcp__sanmartin__get_phase`.
2. After install, `~/.claude/settings.json` is valid JSON containing `mcpServers.sanmartin.url == "https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app"` and `mcpServers.sanmartin.headers["X-API-Key"]` set to the API key passed on the command line.
3. After install, `claude plugin list` includes `sanmartin-mcp@local` with status enabled.
4. After install, the marker file `~/.claude/local-marketplace/.sanmartin-mcp-installed` exists.
5. Running `./install.sh` with no argument, an empty argument, or an API key containing `/` or `"` exits non-zero with a validation error and writes nothing.
6. Running `./install.sh <key>` while `.sanmartin-installed` (beta marker) exists exits non-zero with a "beta detected" message and writes nothing.
7. Running `./uninstall.sh` after a successful install leaves no trace: `~/.claude/local-marketplace/` is gone, `claude plugin list` no longer shows `sanmartin-mcp@local`, and `~/.claude/settings.json` is either restored from `.bak` or absent.
8. The same truths (1-7) hold on Windows when running `install.ps1` / `uninstall.ps1` against `%APPDATA%\Claude\`.

### Artifacts

- `~/.claude/local-marketplace/plugins/sanmartin-mcp/skills/{spec,commit,prd,test-prints}/SKILL.md` — verified by Task 2
- `~/.claude/settings.json` — verified by Tasks 4 (write) and 6 (uninstall)
- `~/.claude/local-marketplace/.sanmartin-mcp-installed` marker — written by Task 4, removed by Task 6
- `claude plugin list` output — verified manually after Tasks 4-7

## Implementation Tasks

### Task 1: Repo scaffolding — marketplace + plugin manifests

**Objective:** Create the static plugin tree so install scripts have something to copy.
**Dependencies:** None

**Files:**

- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/sanmartin-mcp/.claude-plugin/plugin.json`

**Key Decisions / Notes:**

- `marketplace.json` schema mirrors `/Users/sirifacu/Developer/claude-personal-setup/.claude-plugin/marketplace.json:1-15` exactly, swapping the single `plugins[]` entry to `name: "sanmartin-mcp"`, `description: "San Martín Tools — MCP-backed skills"`, `source: "./plugins/sanmartin-mcp"`. Marketplace `name` stays `"local"` so the install command shape (`@local`) matches the beta's mental model.
- `plugin.json` mirrors `/Users/sirifacu/Developer/claude-personal-setup/plugins/personal-tools/.claude-plugin/plugin.json:1-4` with `name: "sanmartin-mcp"` and `description: "San Martín Tools — thin MCP-backed skills (spec, commit, prd, test-prints)"`.
- No `hooks/` directory — the beta's spec hooks are tied to local plan-file lifecycle. The MCP version delegates the workflow to the server; if hooks are needed later we add them in a follow-up.

**Definition of Done:**

- [ ] Both JSON files exist and parse with `python3 -m json.tool`
- [ ] `marketplace.json` references `./plugins/sanmartin-mcp` and `plugin.json` declares the matching plugin name

**Verify:**

- `python3 -m json.tool .claude-plugin/marketplace.json >/dev/null && python3 -m json.tool plugins/sanmartin-mcp/.claude-plugin/plugin.json >/dev/null && echo OK`

---

### Task 2: SKILL.md stubs (4 files)

**Objective:** Ship one thin stub per user-facing slash command. Each stub contains frontmatter mirroring the beta + a single instruction telling Claude to call the MCP `get_phase` tool.
**Dependencies:** Task 1

**Files:**

- Create: `plugins/sanmartin-mcp/skills/spec/SKILL.md`
- Create: `plugins/sanmartin-mcp/skills/commit/SKILL.md`
- Create: `plugins/sanmartin-mcp/skills/prd/SKILL.md`
- Create: `plugins/sanmartin-mcp/skills/test-prints/SKILL.md`

**Key Decisions / Notes:**

- Stub body template (apply to all four):

  ```markdown
  ---
  name: <name>
  description: <description from beta>
  argument-hint: <argument-hint from beta if present>
  user-invocable: true
  effort: low|<unset>   # only for commit and test-prints
  model: <opus|sonnet>
  ---

  # /<name> — MCP-backed San Martín Tools skill

  This is a thin client. All workflow logic lives on the San Martín Tools MCP server.

  ## What to do

  1. Immediately call the MCP tool `mcp__sanmartin__get_phase` with `phase_name: "<phase-string>"`. Pass the user's full argument string (`$ARGUMENTS`) under the `arguments` field.
  2. The tool returns the current workflow instructions for this phase. Follow them exactly using your local tools (Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion).
  3. At every phase transition (e.g. spec-plan → spec-implement, or any time the returned instructions tell you to move to another phase), call `mcp__sanmartin__get_phase` again with the next `phase_name`.
  4. Do not plan, implement, or verify anything from this stub. The server is the source of truth — this file only routes to it.

  If the MCP tool is unavailable or returns an error, stop and report the error to the user verbatim. Do not fall back to local logic.

  ARGUMENTS: $ARGUMENTS
  ```

- Phase-string mapping (use these exact strings):
  - spec → `"spec"`
  - commit → `"commit"`
  - prd → `"prd"`
  - test-prints → `"test_prints"` (underscore — PRD line 81)
- Description text and argument-hint copied verbatim from the beta repo's SKILL.md frontmatter so `/help` output stays identical for testers.
- Model and effort fields preserved from the beta:
  - spec: `model: sonnet`, no effort field (matches `/Users/sirifacu/Developer/claude-personal-setup/plugins/personal-tools/skills/spec/SKILL.md:6`)
  - commit: `model: sonnet`, `effort: low`
  - prd: `model: opus`, no effort field
  - test-prints: `model: sonnet`, `effort: low`

**Definition of Done:**

- [ ] All 4 files exist with valid YAML frontmatter
- [ ] Each file references `mcp__sanmartin__get_phase` exactly once in the body
- [ ] Each file's `phase_name` value matches the mapping above (grep for `phase_name: "spec"` etc.)
- [ ] Description and argument-hint frontmatter values match the beta repo

**Verify:**

- `for f in plugins/sanmartin-mcp/skills/*/SKILL.md; do grep -q "mcp__sanmartin__get_phase" "$f" || echo MISSING: $f; done`
- `grep -h '^phase_name\|"phase_name"\|phase_name:' plugins/sanmartin-mcp/skills/*/SKILL.md` (sanity-check phase strings)

---

### Task 3: settings.json.example template

**Objective:** Provide a settings template the install scripts substitute into. Contains marketplace registration, plugin enable, and the MCP server entry with placeholders.
**Dependencies:** None

**Files:**

- Create: `settings.json.example`

**Key Decisions / Notes:**

- Schema:

  ```json
  {
    "permissions": {
      "allow": [
        "Bash(*)", "Read(*)", "Write(*)", "Edit(*)",
        "Glob(*)", "Grep(*)", "WebFetch(*)", "WebSearch(*)",
        "Agent(*)", "mcp__*__*"
      ]
    },
    "extraKnownMarketplaces": {
      "local": {
        "source": {
          "source": "directory",
          "path": "/Users/YOUR_USERNAME/.claude/local-marketplace"
        }
      }
    },
    "enabledPlugins": {
      "sanmartin-mcp@local": true
    },
    "mcpServers": {
      "sanmartin": {
        "type": "sse",
        "url": "https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app",
        "headers": {
          "X-API-Key": "__SANMARTIN_API_KEY__"
        }
      }
    }
  }
  ```

- Placeholder strings: `/Users/YOUR_USERNAME/.claude/local-marketplace` (path), `YOUR_USERNAME` (Windows fallback string, also substituted), `__SANMARTIN_API_KEY__` (API key). Install scripts substitute all three with literal replacement.
- Permission allowlist matches the beta to avoid permission prompts in the user's existing testing flow.

**Definition of Done:**

- [ ] File exists, parses as JSON
- [ ] Contains the three placeholders verbatim

**Verify:**

- `python3 -m json.tool settings.json.example >/dev/null && grep -c "__SANMARTIN_API_KEY__\|YOUR_USERNAME" settings.json.example` (expect 2+)

---

### Task 4: install.sh (macOS/Linux)

**Objective:** End-to-end installer. Validates env, accepts API key as `$1`, backs up existing config, copies repo to `~/.claude/local-marketplace/`, writes `settings.json` with API key inlined, registers marketplace, installs plugin.
**Dependencies:** Tasks 1-3

**Files:**

- Create: `install.sh` (mode 0755)

**Key Decisions / Notes:**

- Skeleton mirrors `/Users/sirifacu/Developer/claude-personal-setup/install.sh:1-143` step-by-step. Reuse its color helpers, banner, and pre-flight pattern verbatim where applicable.
- Step list:
  1. **Args:** `API_KEY="${1:-}"`. If empty: error `"Usage: ./install.sh <api-key>"`. If `! [[ "$API_KEY" =~ ^[A-Za-z0-9_-]+$ ]]`: error `"API key must contain only letters, digits, underscores, and hyphens."`.
  2. **Repo root check:** `if [ ! -f ".claude-plugin/marketplace.json" ]; then error "Run from repo root"; fi` (matches beta line 24-26).
  3. **Pre-flight:** check `claude` and `git` exist (no `uv` requirement — server-side workflow doesn't need it).
  4. **Beta-collision check:** `if [ -f "$MARKETPLACE_DIR/.sanmartin-installed" ] && [ ! -f "$MARKETPLACE_DIR/.sanmartin-mcp-installed" ]; then error "Beta install detected. Run the beta uninstaller first."; fi`
  5. **Foreign dir check:** `if [ -d "$MARKETPLACE_DIR" ] && [ ! -f "$MARKETPLACE_DIR/.sanmartin-mcp-installed" ]; then error; fi` (after the beta check, so users get the helpful message first).
  6. **Backup:** copy `~/.claude/CLAUDE.md` → `.bak` and `~/.claude/settings.json` → `.bak` if originals exist and no `.bak` already present (matches beta lines 54-69).
  7. **Copy plugin tree:** `rm -rf "$MARKETPLACE_DIR" && mkdir -p "$MARKETPLACE_DIR" && touch "$MARKETPLACE_DIR/.sanmartin-mcp-installed"`. Then rsync the repo with excludes (`.git`, `docs`, `install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`, `README.md`, `*.example`, `.DS_Store`). Fallback to `cp -R` + manual cleanup if rsync missing (matches beta lines 71-107).
  8. **Write settings.json via heredoc:**

     ```bash
     ACTUAL_PATH="$HOME/.claude/local-marketplace"
     cat > "$CLAUDE_DIR/settings.json" <<EOF
     {
       "permissions": { "allow": [ ... ] },
       "extraKnownMarketplaces": {
         "local": {
           "source": { "source": "directory", "path": "$ACTUAL_PATH" }
         }
       },
       "enabledPlugins": { "sanmartin-mcp@local": true },
       "mcpServers": {
         "sanmartin": {
           "type": "sse",
           "url": "https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app",
           "headers": { "X-API-Key": "$API_KEY" }
         }
       }
     }
     EOF
     ```

     The API key is the only variable — already validated in step 1, so the heredoc is safe.
  9. **Register marketplace:** `claude plugin marketplace add "$MARKETPLACE_DIR" --scope user 2>/dev/null || warn "already registered"`.
  10. **Install plugin:** `claude plugin install sanmartin-mcp@local || error "Plugin install failed"`.
  11. **Done banner:** print success and "type / to see /commit /prd /spec /test-prints".

- Constants at top of file: `CLAUDE_DIR`, `MARKETPLACE_DIR`, `MARKER`, `SERVER_URL` (hardcoded).

**Definition of Done:**

- [ ] `bash -n install.sh` passes (syntax check)
- [ ] `shellcheck install.sh` passes (or warnings only — match beta's level)
- [ ] Running with no arg or empty arg exits non-zero with usage error
- [ ] Running with an invalid API key (e.g. `"abc/def"`) exits non-zero
- [ ] Running with `.sanmartin-installed` marker present exits non-zero with the beta-uninstall message
- [ ] After a successful run on a clean machine: marker exists, settings.json contains the API key and URL, `claude plugin list` shows `sanmartin-mcp@local`

**Verify:**

- `bash -n install.sh && shellcheck install.sh || true`
- Manual smoke test on macOS: `./install.sh test-key-12345 && grep "X-API-Key" ~/.claude/settings.json && ls ~/.claude/local-marketplace/.sanmartin-mcp-installed`

---

### Task 5: install.ps1 (Windows)

**Objective:** PowerShell port of `install.sh` — same behavior, same exit codes, paths use `%APPDATA%\Claude\`.
**Dependencies:** Tasks 1-3

**Files:**

- Create: `install.ps1`

**Key Decisions / Notes:**

- Skeleton mirrors `/Users/sirifacu/Developer/claude-personal-setup/install.ps1:1-144` with the same step ordering as Task 4.
- Args: `param([Parameter(Mandatory=$true)][string]$ApiKey)`. PowerShell's `Mandatory=$true` enforces presence; validate the regex with `if ($ApiKey -notmatch '^[A-Za-z0-9_\-]+$') { Write-Fail ... }`.
- Beta-collision check: `if ((Test-Path "$MarketplaceDir\.sanmartin-installed") -and (-not (Test-Path "$MarketplaceDir\.sanmartin-mcp-installed"))) { Write-Fail ... }`
- Copy step: same pattern as beta install.ps1 (Get-ChildItem with exclude list).
- Settings.json write: PowerShell here-string with literal interpolation:

  ```powershell
  $ActualPath = ($MarketplaceDir -replace '\\', '/')
  $Settings = @"
  {
    "permissions": { ... },
    "extraKnownMarketplaces": { "local": { "source": { "source": "directory", "path": "$ActualPath" } } },
    "enabledPlugins": { "sanmartin-mcp@local": true },
    "mcpServers": {
      "sanmartin": {
        "type": "sse",
        "url": "https://san-martin-mcp-web-hnditlm3aq-rj.a.run.app",
        "headers": { "X-API-Key": "$ApiKey" }
      }
    }
  }
  "@
  Set-Content -Path $SettingsJson -Value $Settings -Encoding UTF8
  ```

  `$ApiKey` is regex-validated, so interpolation is safe.

**Definition of Done:**

- [ ] PowerShell parses the file (`pwsh -NoProfile -Command "& { Get-Content ./install.ps1 | Out-Null }"` or equivalent)
- [ ] Mandatory parameter enforces an API key argument
- [ ] Beta-collision check fires before foreign-dir check
- [ ] After a successful run on a Windows test box: marker, settings.json contents, and `claude plugin list` match the macOS truths

**Verify:**

- Static parse: `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('./install.ps1', [ref]$null, [ref]$null) | Out-Null"` (or hand off to a Windows tester)

---

### Task 6: uninstall.sh (macOS/Linux)

**Objective:** Reverse Task 4. Marker check → `claude plugin uninstall` → `claude plugin marketplace remove` → delete marketplace dir → restore `.bak` files (or delete the freshly-installed ones if no backup existed).
**Dependencies:** Task 4

**Files:**

- Create: `uninstall.sh` (mode 0755)

**Key Decisions / Notes:**

- Skeleton mirrors `/Users/sirifacu/Developer/claude-personal-setup/uninstall.sh:1-73`.
- Marker check uses `MARKER="$MARKETPLACE_DIR/.sanmartin-mcp-installed"` (NOT the beta marker). If the marker is missing but `$MARKETPLACE_DIR` exists, abort with "marketplace exists but was not created by this installer" — protects beta installs from being clobbered.
- Plugin uninstall command: `claude plugin uninstall sanmartin-mcp@local`.
- Marketplace remove: `claude plugin marketplace remove local` (same as beta — only one local marketplace allowed at a time).
- Restore order: marketplace → CLAUDE.md backup → settings.json backup. If no backup, delete the file.

**Definition of Done:**

- [ ] `bash -n uninstall.sh` passes
- [ ] Running on a clean machine (no marker) exits 0 with "nothing to do" warning
- [ ] Running on a beta-only install (only `.sanmartin-installed` marker) aborts with the foreign-marker error
- [ ] After running on a successful install: `~/.claude/local-marketplace/` is gone, `claude plugin list` does not show `sanmartin-mcp@local`, `.bak` files restored

**Verify:**

- `bash -n uninstall.sh && shellcheck uninstall.sh || true`

---

### Task 7: uninstall.ps1 (Windows)

**Objective:** PowerShell port of `uninstall.sh`.
**Dependencies:** Task 5

**Files:**

- Create: `uninstall.ps1`

**Key Decisions / Notes:**

- Skeleton mirrors `/Users/sirifacu/Developer/claude-personal-setup/uninstall.ps1:1-85`.
- Marker file path: `$MarketplaceDir\.sanmartin-mcp-installed`.
- Plugin and marketplace commands match Task 6.

**Definition of Done:**

- [ ] PowerShell parses the file
- [ ] Marker check refuses to delete a beta install
- [ ] After running on a successful install: marketplace dir gone, plugin uninstalled, settings.json restored

**Verify:**

- Static parse + Windows tester

---

### Task 8: README.md

**Objective:** End-user install instructions for the public repo. Replaces the current 1-line README.
**Dependencies:** Tasks 4-7

**Files:**

- Modify: `README.md`

**Key Decisions / Notes:**

- Structure mirrors `/Users/sirifacu/Developer/claude-personal-setup/README.md:1-109` but trimmed for the MCP install:
  - 1-paragraph intro: "Thin client for San Martín Tools — slash commands backed by a remote MCP server. You need a beta API key to use it."
  - "What you get" table: `/spec`, `/commit`, `/prd`, `/test-prints` with one-line descriptions copied from the beta GUIDE.md
  - "Prerequisites": Claude Code installed and authenticated; a beta API key (provided by the maintainer)
  - "Installation": macOS/Linux block + Windows block. Each shows: clone → `./install.sh <api-key>` → restart Claude Code.
  - "Updating": `claude plugin update sanmartin-mcp@local`
  - "Uninstalling": `./uninstall.sh` / `./uninstall.ps1`
  - One-line note: "Without a valid API key the slash commands will fail — there is no offline fallback."
- No GUIDE.md — the per-skill behavior is server-defined and may evolve. Linking to the beta GUIDE.md would mislead testers.

**Definition of Done:**

- [ ] README.md replaces the placeholder, contains both OS install blocks, references all 4 slash commands by exact name
- [ ] Every command in the README is copy-pasteable and matches the actual script invocations

**Verify:**

- Manual read-through; cross-check against Tasks 4-7 to ensure command lines agree

---

## Open Questions

None at this point — all design decisions resolved during planning. The MCP `"type": "sse"` schema name is flagged as an assumption in the Risks table; resolution happens during Task 4 implementation when the first end-to-end smoke test runs against the live Cloud Run server.

## Progress Tracking

- [x] Task 1: Repo scaffolding — marketplace + plugin manifests
- [x] Task 2: SKILL.md stubs (4 files)
- [x] Task 3: settings.json.example template
- [x] Task 4: install.sh (macOS/Linux)
- [x] Task 5: install.ps1 (Windows)
- [x] Task 6: uninstall.sh (macOS/Linux)
- [x] Task 7: uninstall.ps1 (Windows)
- [x] Task 8: README.md

**Total Tasks:** 8 | **Completed:** 8 | **Remaining:** 0
