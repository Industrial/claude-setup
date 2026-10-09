#!/usr/bin/env bash
# SessionStart: report whether the lean-ctx CLI is healthy, and always name the
# CLAUDE_ALLOW_NATIVE_TOOLS escape hatch.
#
# Added 2026-10-09 after a session in which the lean-ctx MCP SERVER was not
# connected while the CLI was fine. The routing hooks denied every native tool
# and pointed at ctx_* tools that did not exist, so a read-only audit had no
# file access at all. The hatch existed and no message mentioned it.
#
# HONEST LIMIT, stated so nobody over-trusts this probe: a PreToolUse/SessionStart
# hook is a separate process and CANNOT observe whether Claude Code's MCP client
# has connected to the lean-ctx server. It can only check the CLI. So:
#
#   * CLI missing or unhealthy  -> this probe catches it, and says so loudly.
#   * CLI fine, MCP not connected -> this probe CANNOT detect it. That case is
#     handled structurally instead: block-native-tools.sh now advises rather than
#     denies, so native tools stay available and the session degrades instead of
#     dying. The probe is the second line of defence, not the first.
#
# Output: SessionStart additionalContext (informational; never blocks).
set -euo pipefail

emit() {
    jq -nc --arg ctx "$1" \
        '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
    exit 0
}

note="lean-ctx routing is ADVISORY in this repo: ctx_read/ctx_search/ctx_tree/ctx_shell are preferred, native Read/Grep/Bash/WebFetch are an allowed fallback. Writes go through ctx_patch (ctx_shell refuses '>' redirects). Still denied: unbounded recursive grep, depth-unbounded find, dumping files >64KB, toolchain commands outside 'devenv shell --', and git branch deletion (never bypassable). Escape hatch for everything bypassable: restart with CLAUDE_ALLOW_NATIVE_TOOLS=1."

if ! command -v lean-ctx >/dev/null 2>&1; then
    emit "lean-ctx CLI NOT FOUND on PATH — the devenv shell is probably not active (binaries resolve from .devenv/profile/bin). The ctx_* MCP tools are very likely unavailable too: use native Read/Grep/Bash/Glob, which are allowed, and do not report yourself blocked. ${note}"
fi

if ! timeout 5 lean-ctx --version >/dev/null 2>&1; then
    emit "lean-ctx CLI is on PATH but did not respond to '--version' within 5s — treat the ctx_* MCP tools as unreliable and fall back to native tools, which are allowed. ${note}"
fi

emit "lean-ctx CLI healthy ($(timeout 5 lean-ctx --version 2>/dev/null | head -1)). Note this confirms the CLI only — it cannot confirm the MCP server is connected. If a ctx_* tool is missing from your tool list, that is the MCP server, not the CLI: fall back to native tools rather than retrying. ${note}"
