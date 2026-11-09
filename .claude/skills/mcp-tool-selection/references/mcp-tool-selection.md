# MCP Tool Selection Guide

This document defines the priority order and use cases for each MCP server
used with Hermes Agent. Load the mcp-tool-selection skill at session start to apply these rules automatically.

## Priority Order

| Priority | Server      | Purpose                      | When to use                                                       |
|----------|-------------|------------------------------|--------------------------------------------------------------------|
| 1        | roam-code   | Codebase navigation and understanding | Finding call sites, tracing symbols, mapping dependencies — ALWAYS before reading or editing |
| 2        | lean-ctx    | File reads and all file writes  | `ctx_read` to read, `ctx_patch` to write; never a native `Edit`/`Write` |
| 3        | context7    | Library docs lookup            | Current API docs for third-party libraries; do not rely on training data |
| 4        | searxng     | Web search                     | Anything not in this repository and not a library's docs |

Serena held priority 4 and is removed. Its structural edits are `ctx_patch`'s
(`op="replace_symbol"` renames a function or type in place), and the
navigation it offered is roam-code's, without the language server.

## Tool Selection Rules

- Always **understand with roam-code first** — `roam_context` to orient,
  `roam_preflight` before a structural change. Never open with a grep.
- Always **write with lean-ctx `ctx_patch`** — `op="replace_unique"` for an
  exact snippet (no prior read needed), `op="create"` for a new file,
  `op="replace_symbol"` for a named function or type, `ops: [...]` to batch
  several files atomically. Never a native `Edit` or `Write`.
- Read with **`ctx_read`**, at `signatures`/`map` for context and `full` only
  for files about to be edited
- Use **context7** when the task involves third-party APIs (e.g., Python library functions, npm packages)
- Do not use a shell redirect or `sed -i` as a write substitute — that is what
  `ctx_patch` is for, and `ctx_shell` refuses `>` anyway

## Fallback Behavior

If an MCP server fails to initialize (e.g., import error for `StdioServerParameters`), fall back to the native Hermes tool with same functionality. Log the failure but do not block the session.