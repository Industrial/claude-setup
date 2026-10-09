#!/usr/bin/env bash
# Claude Code port of .cursor/hooks/block-native-*.sh and .hermes/hooks/block-native-tools.sh.
# ROUTES (advises) native file/web tools toward the MCP servers (lean-ctx,
# roam-code, searxng). It no longer DENIES them.
#
# Wire protocol:
#   stdin  : {"hook_event_name":"PreToolUse","tool_name":"<name>","tool_input":{...}}
#   stdout : {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#             "permissionDecision":"allow"|"deny","permissionDecisionReason":"..."}}
#   silent : exit 0 with no stdout (allow, normal permission flow)
#
# ---------------------------------------------------------------------------
# WHY THIS IS ADVISORY AND NOT A DENIAL  (changed 2026-10-09)
#
# These routings used to return permissionDecision=deny. On 2026-10-09 a session
# started while the lean-ctx MCP SERVER was not connected, although the lean-ctx
# CLI was installed and these hooks ran normally. Result: Read, Grep, Bash, Glob
# and WebFetch were all denied, and every tool the denial messages pointed at
# (ctx_read, ctx_search, ctx_shell) did not exist in that session. A read-only
# audit had zero available file access and had to discover, through ToolSearch,
# that the replacements were genuinely absent rather than merely unlisted.
#
# CLAUDE_ALLOW_NATIVE_TOOLS=1 already existed as an escape hatch, and still
# does. It did not help, for one reason: NONE OF THE DENIAL MESSAGES MENTIONED
# IT. An agent cannot export an env var for its own already-running session, and
# nothing told it to ask the user to. The hatch was real and undiscoverable.
#
# The asymmetry decides it. The routing's benefit is OPPORTUNISTIC: it pays off
# when the MCP tools are reachable and costs nothing when they are not. The
# denial is STRUCTURAL: it adds nothing when the tools work and costs the whole
# session when they do not. So: advise always, deny never (here), and name the
# hatch in every message. Expensive-by-construction shell commands are still
# denied — see guard-bash.sh.
#
# Also note nothing in lean-ctx's own documentation asks for mandatory routing;
# its install path is `lean-ctx setup`, and hooks are one of four optional
# integration paths (CLI, MCP, hooks, proxy).
# ---------------------------------------------------------------------------
set -euo pipefail

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty')"

# Fully silent when the operator has opted out of routing advice entirely.
if [ "${CLAUDE_ALLOW_NATIVE_TOOLS:-0}" = "1" ]; then
    exit 0
fi

# Advise and allow. The reason text reaches the model; the call proceeds.
advise() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:$reason}}'
    exit 0
}

PREFER="Preferred, not required: "
FALLBACK=" If that tool is unavailable (MCP server not connected), this native call is the correct fallback — it is allowed, so proceed rather than reporting yourself blocked."

case "$tool_name" in
    Read)
        advise "${PREFER}lean-ctx ctx_read is cheaper than native Read. Modes: full (before edit), anchored (full + anchors for ctx_patch), map (deps/exports), signatures (API surface), diff (after edit), lines:N-M (range), auto (default). Re-reads are cached (~13 tokens).${FALLBACK}"
        ;;
    Grep)
        advise "${PREFER}lean-ctx ctx_search returns more compact results than native Grep. For directory listings use ctx_tree; for symbol or meaning-based exploration use roam-code (roam_search_symbol, roam_context, roam_uses, roam_explore).${FALLBACK}"
        ;;
    WebSearch)
        advise "${PREFER}searxng_web_search (local SearXNG at http://localhost:4001) keeps web results local.${FALLBACK}"
        ;;
    WebFetch)
        advise "${PREFER}searxng web_url_read handles general URLs and paginates large pages; for library or framework API docs use context7 (resolve-library-id, then query-docs).${FALLBACK}"
        ;;
    Edit|Write|NotebookEdit)
        # Deliberately SILENT rather than permissionDecision=allow.
        #
        # guard-write-paths.sh and guard-id-mode.sh also match these tools. An
        # explicit "allow" from this hook risks being read as a decision that
        # competes with their denials, which are real safety rails (path jail,
        # ID mode write bans). Staying silent leaves those two in sole charge
        # and lets the write proceed through the normal permission flow.
        #
        # ctx_patch remains the house edit path (op=replace_unique / op=create,
        # ops[] to batch same-file edits) and is documented in .claude/CLAUDE.md.
        # Native Edit/Write are a working fallback when lean-ctx is unreachable.
        exit 0
        ;;
esac

exit 0
