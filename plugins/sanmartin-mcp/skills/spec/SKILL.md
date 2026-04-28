---
name: spec
description: Spec-driven development - plan, implement, verify workflow. Routes to the appropriate phase based on task type and plan status.
argument-hint: "<task description>" or "<path/to/plan.md>"
user-invocable: true
model: sonnet
---

# /spec — MCP-backed San Martín Tools skill

This is a thin client. All workflow logic lives on the San Martín Tools MCP server.

## What to do

1. Immediately call the MCP tool `mcp__sanmartin__get_phase` with `phase_name: "spec"`. Pass the user's full argument string under the `arguments` field.
2. The tool returns the current workflow instructions for this phase. Follow them exactly using your local tools (Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion).
3. At every phase transition (e.g. spec-plan → spec-implement, or any time the returned instructions tell you to move to another phase), call `mcp__sanmartin__get_phase` again with the next `phase_name`.
4. Do not plan, implement, or verify anything from this stub. The server is the source of truth — this file only routes to it.

If the MCP tool is unavailable or returns an error, stop and report the error to the user verbatim. Do not fall back to local logic.

ARGUMENTS: $ARGUMENTS
