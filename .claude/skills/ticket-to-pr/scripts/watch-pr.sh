#!/usr/bin/env bash
# Watch a PR's checks to a terminal state and, when red, put the failing logs
# on disk where the agent can read them.
#
# Run it through ctx_shell with run_in_background:true and a timeout_ms that
# covers the whole CI run, then poll with background_action:"status".
#
# Usage:  bash .claude/skills/ticket-to-pr/scripts/watch-pr.sh [<pr>] [--interval 30] [--timeout-min 45]
# Exit:   0 green | 1 red (logs written) | 2 timed out | 3 no checks ever appeared
set -uo pipefail

pr=""
interval=30
timeout_min=45
while [ $# -gt 0 ]; do
    case "$1" in
        --interval) interval="${2:?}"; shift 2 ;;
        --timeout-min) timeout_min="${2:?}"; shift 2 ;;
        -*) echo "unknown flag $1" >&2; exit 64 ;;
        *) pr="$1"; shift ;;
    esac
done

repo_root="$(git rev-parse --show-toplevel)"
logs="$repo_root/.tmp/ci"
mkdir -p "$logs"

if [ -z "$pr" ]; then
    pr="$(gh pr view --json number --jq .number 2>/dev/null || true)"
fi
[ -n "$pr" ] || { echo "no PR for this branch and none given" >&2; exit 64; }

deadline=$(( $(date +%s) + timeout_min * 60 ))

while :; do
    snapshot="$(gh pr checks "$pr" --json name,state,bucket,link 2>/dev/null || true)"

    if [ -z "$snapshot" ] || [ "$snapshot" = "[]" ]; then
        [ "$(date +%s)" -ge "$deadline" ] && { echo "PR #$pr: no checks appeared within ${timeout_min}m"; exit 3; }
        echo "PR #$pr: waiting for checks to register…"
        sleep "$interval"
        continue
    fi

    pending="$(printf '%s' "$snapshot" | jq -r '[.[] | select(.bucket == "pending")] | length')"
    failed="$(printf '%s' "$snapshot" | jq -r '[.[] | select(.bucket == "fail" or .bucket == "cancel")] | length')"

    printf '%s  PR #%s  pending=%s failed=%s total=%s\n' \
        "$(date -u +%H:%M:%S)" "$pr" "$pending" "$failed" \
        "$(printf '%s' "$snapshot" | jq -r 'length')"

    if [ "$pending" -eq 0 ]; then
        if [ "$failed" -eq 0 ]; then
            echo "PR #$pr: GREEN"
            printf '%s' "$snapshot" | jq -r '.[] | "  ok   \(.name)"'
            exit 0
        fi

        echo "PR #$pr: RED"
        printf '%s' "$snapshot" | jq -r '.[] | select(.bucket == "fail" or .bucket == "cancel") | "  fail \(.name)  \(.link)"'

        # One log file per failing run — gh run view --log-failed prints only the
        # failing steps, which is the part worth reading.
        printf '%s' "$snapshot" \
            | jq -r '.[] | select(.bucket == "fail" or .bucket == "cancel") | .link' \
            | sed -nE 's#.*/actions/runs/([0-9]+).*#\1#p' \
            | sort -u \
            | while IFS= read -r run; do
                [ -n "$run" ] || continue
                gh run view "$run" --log-failed > "$logs/pr-$pr-run-$run.log" 2>&1 || true
                printf '  log  .tmp/ci/pr-%s-run-%s.log (%s lines)\n' \
                    "$pr" "$run" "$(wc -l < "$logs/pr-$pr-run-$run.log")"
            done
        exit 1
    fi

    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "PR #$pr: still pending after ${timeout_min}m — timed out"
        exit 2
    fi
    sleep "$interval"
done
