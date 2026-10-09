#!/usr/bin/env bash
# Claude Code guard for the Bash tool. Merges three upstream hooks:
#   .hermes/hooks/block-git-branch-delete.sh  (SOUL.md hard rule)
#   .cursor/hooks/block-native-shell.sh       (route shell through ctx_shell)
#   .cursor/hooks/enforce-devenv.sh           (wrap commands in `devenv shell --`)
#
# Order matters. The branch-delete guard is a safety rule, not a routing rule,
# so it runs first and is NOT bypassable by CLAUDE_ALLOW_NATIVE_TOOLS.
set -euo pipefail

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .toolName // empty')"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

[ "$tool_name" = "Bash" ] || exit 0
[ -n "$command" ] || exit 0

deny() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
}

# ---- 1. git branch deletion: always blocked, never bypassable ----------------
cmd_lower="$(printf '%s' "$command" | tr '[:upper:]' '[:lower:]')"
segments="$(printf '%s' "$cmd_lower" | tr ';|&\n' '\n')"

while IFS= read -r segment || [ -n "$segment" ]; do
    segment="$(printf '%s' "$segment" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -z "$segment" ] && continue

    if printf '%s' "$segment" | grep -Eq '\bgit[[:space:]]+branch\b[^;|&]*(-D\b|-d\b|--delete\b)'; then
        deny "Forbidden: never delete git branches (git branch -d/-D/--delete). Ask the user to delete branches manually. See SOUL.md and .hermes/hooks/block-git-branch-delete.sh."
    fi

    if printf '%s' "$segment" | grep -Eq '\bgit[[:space:]]+push\b[^;|&]*(--delete\b|:[^[:space:];|&]+)'; then
        deny "Forbidden: never delete remote git branches (git push --delete or git push :branch). Ask the user to delete branches manually. See SOUL.md and .hermes/hooks/block-git-branch-delete.sh."
    fi
done <<< "$segments"

# ---- 2. expensive-by-construction reads: still denied ------------------------
#
# Changed 2026-10-09: this section used to deny EVERY Bash command. That made a
# lean-ctx MCP outage fatal — see the header of block-native-tools.sh for the
# session that proved it. Ordinary commands are now allowed with routing advice;
# only commands whose cost is bad by construction are refused, because for those
# the ctx_* equivalent is not a preference but a materially different operation.
#
# Bypassable by CLAUDE_ALLOW_NATIVE_TOOLS=1, like the old blanket denial was.

advise() {
    jq -nc --arg reason "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:$reason}}'
    exit 0
}

HATCH=" If you need this exact command, ask the user to restart with CLAUDE_ALLOW_NATIVE_TOOLS=1 — an agent cannot set it for its own running session."

if [ "${CLAUDE_ALLOW_NATIVE_TOOLS:-0}" != "1" ]; then

    # 2a. Unbounded recursive search. The compressed equivalent is ctx_search.
    if printf '%s' "$command" | grep -Eq '(^|[;|&[:space:]])(grep|rg)[[:space:]]+(-[[:alnum:]]*[rR][[:alnum:]]*[[:space:]]+)' \
        && ! printf '%s' "$command" | grep -Eq '(--include|--exclude|-g[[:space:]]|--glob|--max-count|-m[[:space:]]|head|-l[[:space:]]*$)'; then
        deny "Unbounded recursive search refused: this returns the whole match set uncompressed and has repeatedly flooded the context. Use ctx_search(pattern=..., path=..., include=\"*.py\") which returns compact results, or add --include/--max-count to bound it.${HATCH}"
    fi

    # 2b. Whole-tree find with no depth bound. Real case 2026-10-09: one such
    #     command spilled 55,000 chars into an out-of-band archive and cost an
    #     extra round trip on a question `ls` answers.
    if printf '%s' "$command" | grep -Eq '(^|[;|&[:space:]])find[[:space:]]' \
        && ! printf '%s' "$command" | grep -Eq '(-maxdepth|head|-quit)'; then
        deny "Unbounded 'find' refused: on this repo it returns thousands of paths and gets spilled to an archive, costing a round trip. Use ctx_glob(pattern=\"**/NAME\") or ctx_tree(path=..., depth=N), or add -maxdepth.${HATCH}"
    fi

    # 2c. Dumping a large file. Threshold is deliberately generous; the point is
    #     to catch `cat <bigfile>`, not to police small reads.
    for tok in $command; do
        case "$tok" in
            -*|*'*'*|*'?'*) continue ;;
        esac
        if printf '%s' "$command" | grep -Eq "(^|[;|&[:space:]])(cat|head|tail)[[:space:]]" \
            && [ -f "$tok" ] && [ "$(wc -c < "$tok" 2>/dev/null || echo 0)" -gt 65536 ]; then
            deny "Refusing to dump '$tok' ($(( $(wc -c < "$tok") / 1024 )) KB) into context. Use ctx_read(path=\"$tok\", mode=\"signatures\") for the API surface, mode=\"map\" for structure, or mode=\"lines:N-M\" for a window.${HATCH}"
        fi
    done
fi

# ---- 3. devenv wrapping: toolchain commands, in devenv projects only ---------
#
# TWO narrowings, both load-bearing. Do not collapse them.
#
# (a) WHERE. This payload also deploys to ~/.claude, so the hook runs in every
#     directory the user ever opens Claude in, not just devenv projects.
#     Demanding `devenv shell --` in ~, /tmp or a non-devenv repo denies every
#     command with advice that cannot be followed there: `devenv shell` fails
#     without a devenv.nix, so the session has no working shell at all. Enforce
#     the wrap only where it can succeed. PRE-EXISTING FIX, preserved on merge.
#
# (b) WHICH. Previously every command had to be wrapped, which is
# needless ceremony for `ls`, `git status` or `jq`. The requirement is real only
# for commands that need the pinned toolchain or the shell's env (TMPDIR,
# CARGO_DRIFT_FFI_PATH, LD_LIBRARY_PATH, NATS_URL, PYTHONPATH) — see AGENTS.md.
trimmed="$(printf '%s' "$command" | sed 's/^[[:space:]]*//')"
case "$trimmed" in
    "devenv shell --"*) exit 0 ;;
esac

hook_cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
repo="${CLAUDE_PROJECT_DIR:-${hook_cwd:-$PWD}}"

if [ -f "$repo/devenv.nix" ] \
    && { printf '%s' "$trimmed" | grep -Eq '(^|[;|&[:space:]])(moon|pytest|ruff|ty|uv|cargo|maestro|assay|treefmt|prek|freqtrade)([[:space:]]|$)' \
        || printf '%s' "$trimmed" | grep -Eq '(^|[;|&[:space:]])python3?([[:space:]]|$)'; }; then
    deny "Toolchain commands must run inside the devenv shell, which supplies the pinned binaries and the env (TMPDIR, LD_LIBRARY_PATH, NATS_URL=…:14222, PYTHONPATH). Re-run as: devenv shell -- $trimmed${HATCH}"
fi

# ---- 4. everything else: advise the compressed path, then allow --------------
if [ "${CLAUDE_ALLOW_NATIVE_TOOLS:-0}" != "1" ]; then
    advise "Preferred, not required: lean-ctx ctx_shell applies pattern compression to git/npm/cargo/docker output, and ctx_read/ctx_search/ctx_tree beat cat/grep/ls for reading code. If those MCP tools are unavailable this native call is the correct fallback — it is allowed, so proceed rather than reporting yourself blocked. Note ctx_shell refuses '>' redirects; file writes go through ctx_patch (op=create / op=replace_unique)."
fi

exit 0
