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

# 2c. Dumping a large file into context.
#
# Rewritten 2026-11-12 after a peer session lost ~15 minutes and filed a
# confidently wrong report off the back of this check. The old test asked
# whether the words cat/head/tail appeared ANYWHERE in the command, then
# denied if ANY whitespace-split token was a >64KB file. The two halves were
# never correlated, so the big file did not have to be an argument of
# anything. Three distinct failures came out of that:
#
#   (a) A heredoc body that merely MENTIONED a 1 MB path was tokenised, so
#       `... <<PY ... PY | tail -3` was refused for a command that read no
#       file at all. Heredoc bodies are data, not arguments — they are
#       stripped before tokenising now.
#
#   (b) `git push origin main > .tmp/push.log 2>&1; ...; tail -12 .tmp/push.log`
#       was refused IN FULL because .tmp/push.log already existed at 274 KB
#       from an earlier run. The push never happened, but the wording read as
#       a read refusal, so the session went on to diagnose a day-old log in
#       detail. Hence: redirect targets are writes, not reads, and the deny
#       text now says outright that nothing ran.
#
#   (c) `tail -12` on a 274 KB file was treated as a dump. head and tail are
#       bounded by construction — they default to 10 lines. They are refused
#       only when the count asked for is itself unbounded (a huge -n/-c, or
#       `tail -n +N` / `head -n -N`, which both mean "the rest of the file").
#
# A basename comparison also closes a false negative the old regex had:
# `/usr/bin/cat bigfile` was allowed, because the pattern wanted cat at a
# word boundary.
#
# Thresholds stay generous. The point is to catch `cat <bigfile>`, not to
# police small reads.

DUMP_SIZE_CAP=65536   # file size above which an unbounded read is refused
DUMP_LINE_CAP=5000    # -n above this is not a window any more
DUMP_BYTE_CAP=65536   # -c above this is not a window any more

# Does an explicit count ask for effectively the whole file?
# $1 = value as written, $2 = cap, $3 = which dumper. 0 = unbounded.
dump_count_unbounded() {
    local val="$1" cap="$2" who="$3" n mult=1
    case "$val" in
        +*) [ "$who" = tail ] && return 0 || return 1 ;;
        -*) [ "$who" = head ] && return 0 || return 1 ;;
    esac
    case "$val" in
        *[gGmM]|*[gGmM]B) return 0 ;;
        *[kK]|*[kK]B) mult=1024 ;;
    esac
    n="${val%%[!0-9]*}"
    [ -n "$n" ] || return 1
    [ "$(( n * mult ))" -gt "$cap" ] && return 0
    return 1
}

# Heredoc bodies are data. Drop them before anything is tokenised.
dump_scan="$(printf '%s\n' "$command" | awk '
        BEGIN { delim = "" }
        {
            if (delim != "") {
                line = $0
                sub(/^[ \t]+/, "", line)
                if (line == delim) { delim = "" }
                next
            }
            if (match($0, /<<-?[ \t]*[\042\047]?[A-Za-z_][A-Za-z0-9_]*[\042\047]?/)) {
                tag = substr($0, RSTART, RLENGTH)
                sub(/^<<-?[ \t]*/, "", tag)
                gsub(/[\042\047]/, "", tag)
                delim = tag
            }
            print
        }')"

    # Walk segment by segment. A file counts only as the argument of a dumping
    # command in the same segment, so `grep x big | tail -3` reads big through
    # grep (bounded output) and tail never sees a file at all.
    set -f
    while IFS= read -r dump_seg || [ -n "$dump_seg" ]; do
        [ -z "$dump_seg" ] && continue
        dumper=""; dump_unbounded=0; dump_cap=0; dump_skip=0
        for tok in $dump_seg; do
            # trailing separators survive the split on ; | &
            tok="${tok%%[;|&]}"
            [ -z "$tok" ] && continue

            if [ "$dump_skip" = 1 ]; then dump_skip=0; continue; fi

            # a count whose flag came as a separate token (-n 50 / -c 1M)
            if [ "$dump_cap" != 0 ]; then
                dump_count_unbounded "$tok" "$dump_cap" "$dumper" && dump_unbounded=1
                dump_cap=0
                continue
            fi

            # Output redirections: the target is written, never read.
            case "$tok" in
                '>'|'>>'|'1>'|'1>>'|'2>'|'2>>'|'&>'|'&>>'|'>|') dump_skip=1; continue ;;
                '>'*|'1>'*|'2>'*|'&>'*) continue ;;
            esac
            # Input redirections DO read: `cat < bigfile` is a dump.
            case "$tok" in
                '<<'*) continue ;;
                '<') continue ;;
                '<'*) tok="${tok#<}" ;;
            esac

            case "${tok##*/}" in
                cat)       dumper=cat; dump_unbounded=1; continue ;;
                head|tail) dumper="${tok##*/}"; dump_unbounded=0; continue ;;
            esac

            [ -n "$dumper" ] || continue

            case "$tok" in
                -n|--lines) dump_cap="$DUMP_LINE_CAP"; continue ;;
                -c|--bytes) dump_cap="$DUMP_BYTE_CAP"; continue ;;
                --lines=*)  dump_count_unbounded "${tok#*=}" "$DUMP_LINE_CAP" "$dumper" && dump_unbounded=1; continue ;;
                --bytes=*)  dump_count_unbounded "${tok#*=}" "$DUMP_BYTE_CAP" "$dumper" && dump_unbounded=1; continue ;;
                -n*)        dump_count_unbounded "${tok#??}" "$DUMP_LINE_CAP" "$dumper" && dump_unbounded=1; continue ;;
                -c*)        dump_count_unbounded "${tok#??}" "$DUMP_BYTE_CAP" "$dumper" && dump_unbounded=1; continue ;;
                -[0-9]*)    dump_count_unbounded "${tok#-}"  "$DUMP_LINE_CAP" "$dumper" && dump_unbounded=1; continue ;;
                -*)         continue ;;
            esac

            [ "$dump_unbounded" = 1 ] || continue
            [ -f "$tok" ] || continue
            dump_size="$(wc -c < "$tok" 2>/dev/null || echo 0)"
            if [ "$dump_size" -gt "$DUMP_SIZE_CAP" ]; then
                set +f
                deny "Nothing ran — this command was refused before execution, so any side effect it also had (a push, a build, a redirect) did NOT happen. It would dump '$tok' ($(( dump_size / 1024 )) KB) into context via '$dumper'. Use ctx_read(path=\"$tok\", mode=\"signatures\") for the API surface, mode=\"map\" for structure, or mode=\"lines:N-M\" for a window; a bounded 'head -20' / 'tail -50' is allowed.${HATCH}"
            fi
        done
    done <<< "$(printf '%s' "$dump_scan" | tr ';|&\n' '\n')"
    set +f
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
