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
#   7. The large-file guard (2c) fires on unbounded dumps and ONLY on those —
#      added 2026-11-12 with the rewrite of that section; see guard-bash.sh for
#      the three false positives that motivated it.
#
# Usage: bash test-advisory-routing.sh
# Exit 0 = all pass. Exit 1 = at least one failure (names printed).
set -uo pipefail
cd "$(dirname "$0")"

pass=0; fail=0

# The hook reads .cwd to decide whether the devenv wrap applies. Without it
# section 3 is skipped entirely and the devenv cases below pass as "allow" —
# which is how this suite came to report two spurious failures. Walk up to the
# nearest devenv.nix and pass that as the session cwd.
repo_root="$(while [ ! -f devenv.nix ] && [ "$PWD" != / ]; do cd ..; done; pwd)"
[ -f "$repo_root/devenv.nix" ] || printf 'warn: no devenv.nix above %s; devenv cases will fail\n' "$PWD"

# Fixtures for the large-file guard.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
big="$tmpdir/big.log"
small="$tmpdir/small.log"
dd if=/dev/zero bs=1024 count=128 2>/dev/null | base64 > "$big"
printf 'one line\n' > "$small"
catbin="$(command -v cat)"

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
    local json; json="$(jq -nc --arg c "$2" --arg d "$repo_root" \
        '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}')"
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

echo "large-file dumps: refuse only the unbounded ones"
cmd "cat bigfile"              "cat $big"                          deny
cmd "cat bigfile | grep"       "cat $big | grep x"                 deny
cmd "cat by absolute path"     "$catbin $big"                      deny
cmd "cat < bigfile"            "cat < $big"                        deny
cmd "cat after &&"             "git status && cat $big"            deny
cmd "head -n huge"             "head -n 999999 $big"               deny
cmd "head -c over byte cap"    "head -c 200000 $big"               deny
cmd "tail -n +1 (whole file)"  "tail -n +1 $big"                   deny

echo "large-file guard: must NOT fire on bounded or unrelated reads"
cmd "bounded tail"             "tail -12 $big"                     allow
cmd "bounded head"             "head -20 $big"                     allow
cmd "head -c under byte cap"   "head -c 400 $big"                  allow
cmd "cat of a small file"      "cat $small"                        allow
cmd "bigfile is redirect target" "echo hi > $big; tail -2 /dev/null" allow
cmd "bigfile named, no dumper" "ls -la $big"                       allow
cmd "grep bigfile | tail"      "grep -c x $big | tail -1"          allow
cmd "push then bounded tail"   "git push origin main > $big 2>&1; echo rc=\$?; tail -12 $big" allow
cmd "heredoc merely names it"  "sed -n 1,2p <<EOF | tail -3
mentions $big but reads nothing
EOF"                                                               allow

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
cmd "cat bigfile under hatch"      "cat $big"                      SILENT
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
