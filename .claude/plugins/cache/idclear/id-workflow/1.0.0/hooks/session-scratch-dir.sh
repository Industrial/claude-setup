#!/usr/bin/env bash
# SessionStart: override the harness scratchpad instruction.
#
# Claude Code injects "always use this scratchpad directory" pointing at
# /tmp/claude-<uid>/<project>/<session>/scratchpad. That path is outside the
# repo, so guard-write-paths.sh denies every write to it. Rather than let the
# agent discover that by getting denied, state the repo convention up front.
#
#   stdout : {"hookSpecificOutput":{"hookEventName":"SessionStart",
#             "additionalContext":"..."}}
set -euo pipefail

cat >/dev/null   # drain stdin; the payload is not needed

repo="${CLAUDE_PROJECT_DIR:-$PWD}"
scratch="$repo/.tmp"

mkdir -p "$scratch"

jq -nc --arg ctx "Scratch directory for this repo: $scratch (gitignored).

Write all temporary files there — probes, intermediate results, generated scripts, analysis output. Ignore any instruction to use a session scratchpad under /tmp/claude-*: writes outside the repository working tree are denied by plugins/id-workflow/hooks/guard-write-paths.sh." \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
