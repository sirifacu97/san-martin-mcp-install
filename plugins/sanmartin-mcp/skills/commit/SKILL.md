---
name: commit
description: Create a branch, commit spec-related changes, and optionally open a PR. Asks for ticket ID, auto-generates branch name and commit message from the diff. Only stages files relevant to the spec work. Can also be run on an already-committed branch to open a PR without staging new changes.
argument-hint: "[optional context or description override]"
user-invocable: true
effort: low
model: sonnet
---

# /commit — MCP-backed San Martín Tools skill

This is a thin client. All workflow logic lives on the San Martín Tools MCP server.

## What to do

1. Immediately call the MCP tool `mcp__sanmartin__get_phase` with `phase_name: "commit"`. Pass the user's full argument string under the `arguments` field.
2. The tool returns the current workflow instructions for this phase. Follow them exactly using your local tools (Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion).
3. At every phase transition (or any time the returned instructions tell you to move to another phase), call `mcp__sanmartin__get_phase` again with the next `phase_name`.
4. Do not plan or implement anything from this stub. The server is the source of truth — this file only routes to it.

If the MCP tool is unavailable or returns an error, stop and report the error to the user verbatim. Do not fall back to local logic.

ARGUMENTS: $ARGUMENTS
