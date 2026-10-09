#!/usr/bin/env bash
# Acceptance test for advisory tool routing (added 2026-10-09).
#
# Fences the regression that motivated the change: a lean-ctx MCP outage used to
# leave a session with no file access at all, because every native tool was
# denied and the ctx_* replacements did not exist.
#
# What this asserts:
#   1. Read / Grep / WebFetch / WebSearch are ALLOWED (advisory), never denied.
#   2. Edit / Write stay SILENT so guard-write-paths + guard-id-mode keep sole
#      authority over writes.
#   3. Ordinary Bash is ALLOWED with advice.
#   4. Expensive-by-construction Bash is still DENIED.
#   5. git branch deletion is DENIED even with the escape hatch set.
#   6. CLAUDE_ALLOW_NATIVE_TOOLS=1 silences routing but not the safety rule.
#
# Usage: bash test-advisory-routing.sh
# Exit 0 = all pass. Exit 1 = at least one failure (names printed).
set -uo pipefail
cd "$(dirname "$0")"

pass=0; fail=0

decide() { # <script> <json> -> "allow" | "deny" | "SILENT"
    local out
    out="$(printf '%s' "$2" | bash "$1" 2>/dev/null)"
    if [ -z "$out" ]; then printf 'SILENT'; return; fi
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "SILENT"'
}

check() { # <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
        pass=$((pass+1)); printf '  ok    %-46s %s\n' "$1" "$3"
    else
        fail=$((fail+1)); printf '  FAIL  %-46s expected=%s got=%s\n' "$1" "$2" "$3"
    fi
}

tool() { # <label> <toolname> <expected>
    check "$1" "$3" "$(decide block-native-tools.sh "{\"tool_name\":\"$2\",\"tool_input\":{}}")"
}

cmd() { # <label> <command> <expected>
    local json; json="$(jq -nc --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}')"
    check "$1" "$3" "$(decide guard-bash.sh "$json")"
}

echo "native file/web tools (must never deny)"
tool "Read advises, allows"        Read       allow
tool "Grep advises, allows"        Grep       allow
tool "WebFetch advises, allows"    WebFetch   allow
tool "WebSearch advises, allows"   WebSearch  allow
tool "Write stays silent"          Write      SILENT
tool "Edit stays silent"           Edit       SILENT
tool "NotebookEdit stays silent"   NotebookEdit SILENT

echo "ordinary shell (must allow)"
cmd "ls"                       'ls -la'                            allow
cmd "git status"               'git status --porcelain'            allow
cmd "jq"                       'jq . package.json'                 allow
cmd "bounded grep"             'grep -r foo . --include=*.py'      allow
cmd "bounded find"             'find . -maxdepth 2 -name x'        allow
cmd "sed read"                 'sed -n 1,20p AGENTS.md'            allow

echo "expensive by construction (must deny)"
cmd "unbounded recursive grep" 'grep -r foo .'                     deny
cmd "unbounded rg"             'rg -r foo .'                       deny
cmd "depth-unbounded find"     'find . -name SKILL.md'             deny

echo "devenv requirement (toolchain only)"
cmd "bare pytest"              'pytest -q'                         deny
cmd "bare moon"                'moon run :test'                    deny
cmd "wrapped pytest"           'devenv shell -- pytest -q'         SILENT

echo "safety rule (never bypassable)"
cmd "git branch -D"            'git branch -D feature'             deny
cmd "git branch --delete"      'git branch --delete feature'       deny
cmd "git push :branch"         'git push origin :feature'          deny

echo "escape hatch: routing off, safety on"
export CLAUDE_ALLOW_NATIVE_TOOLS=1
tool "Read silent under hatch"     Read   SILENT
cmd "ls silent under hatch"        'ls -la'                        SILENT
cmd "grep -r allowed under hatch"  'grep -r foo .'                 SILENT
cmd "branch delete STILL denied"   'git branch -D feature'         deny
unset CLAUDE_ALLOW_NATIVE_TOOLS

echo "probe never blocks"
probe_out="$(bash lean-ctx-probe.sh </dev/null 2>/dev/null)"
check "probe emits SessionStart context" "SessionStart" \
    "$(printf '%s' "$probe_out" | jq -r '.hookSpecificOutput.hookEventName // "none"')"
check "probe names the escape hatch" "yes" \
    "$(printf '%s' "$probe_out" | grep -q CLAUDE_ALLOW_NATIVE_TOOLS && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
