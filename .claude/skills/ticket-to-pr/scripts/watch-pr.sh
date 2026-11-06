#!/usr/bin/env bash
# Watch a PR from "checks running" all the way to **merged**, and when red put
# the failing logs on disk where the agent can read them.
#
# Green is not the finish line: a PR can be green and still unmerged because it
# is behind its base, awaiting a required review, conflicted, or still a draft.
# This script tells those apart so the agent knows whether to fix, wait, or hand
# back to the human.
#
# Run it through ctx_shell with run_in_background:true and a timeout_ms that
# covers the whole CI run plus the merge, then poll with background_action:"status".
#
# Usage:  bash .claude/skills/ticket-to-pr/scripts/watch-pr.sh [<pr>] \
    #             [--interval 30] [--timeout-min 45] \
    #             [--no-merge-wait] [--merge-method squash|merge|rebase] [--no-update-branch]
#
# Exit:   0 merged (or green, with --no-merge-wait)
#         1 red — failing logs written to .tmp/ci/
#         2 timed out
#         3 no checks ever appeared
#         4 green but the merge is blocked and needs a human
#         5 PR closed without merging
set -uo pipefail

pr=""
interval=30
timeout_min=45
merge_wait=1
merge_method="squash"
update_branch=1
while [ $# -gt 0 ]; do
    case "$1" in
        --interval) interval="${2:?}"; shift 2 ;;
        --timeout-min) timeout_min="${2:?}"; shift 2 ;;
        --no-merge-wait) merge_wait=0; shift ;;
        --merge-method) merge_method="${2:?}"; shift 2 ;;
        --no-update-branch) update_branch=0; shift ;;
        -*) echo "unknown flag $1" >&2; exit 64 ;;
        *) pr="$1"; shift ;;
    esac
done

case "$merge_method" in
    squash|merge|rebase) ;;
    *) echo "--merge-method must be squash|merge|rebase" >&2; exit 64 ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
logs="$repo_root/.tmp/ci"
mkdir -p "$logs"

if [ -z "$pr" ]; then
    pr="$(gh pr view --json number --jq .number 2>/dev/null || true)"
fi
[ -n "$pr" ] || { echo "no PR for this branch and none given" >&2; exit 64; }

deadline=$(( $(date +%s) + timeout_min * 60 ))

# gh pr view in one shot — state, merge state, review gate, auto-merge flag.
pr_state() {
    gh pr view "$pr" \
        --json state,mergeStateStatus,mergeable,reviewDecision,autoMergeRequest,isDraft \
        2>/dev/null || true
}

updates_attempted=0
merge_attempted=0

while :; do
    meta="$(pr_state)"
    state="$(printf '%s' "$meta" | jq -r '.state // "UNKNOWN"')"

    # Terminal states first — a merge that landed between polls must not be
    # misread as "still pending".
    if [ "$state" = "MERGED" ]; then
        echo "PR #$pr: MERGED"
        exit 0
    fi
    if [ "$state" = "CLOSED" ]; then
        echo "PR #$pr: CLOSED without merging — needs a human"
        exit 5
    fi

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

    if [ "$pending" -eq 0 ] && [ "$failed" -gt 0 ]; then
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

    if [ "$pending" -eq 0 ] && [ "$failed" -eq 0 ]; then
        echo "PR #$pr: GREEN"
        printf '%s' "$snapshot" | jq -r '.[] | "  ok   \(.name)"'

        if [ "$merge_wait" -eq 0 ]; then
            exit 0
        fi

        merge_state="$(printf '%s' "$meta" | jq -r '.mergeStateStatus // "UNKNOWN"')"
        mergeable="$(printf '%s' "$meta" | jq -r '.mergeable // "UNKNOWN"')"
        review="$(printf '%s' "$meta" | jq -r '.reviewDecision // ""')"
        auto="$(printf '%s' "$meta" | jq -r 'if .autoMergeRequest == null then "off" else "on" end')"
        draft="$(printf '%s' "$meta" | jq -r '.isDraft // false')"

        echo "  merge: state=$merge_state mergeable=$mergeable review=${review:-none} auto-merge=$auto draft=$draft"

        # Blockers a human owns. Bail with a precise reason rather than
        # spinning to the timeout.
        if [ "$draft" = "true" ]; then
            echo "PR #$pr: green but still a DRAFT — mark it ready for review"
            exit 4
        fi
        if [ "$merge_state" = "DIRTY" ] || [ "$mergeable" = "CONFLICTING" ]; then
            echo "PR #$pr: green but CONFLICTING with the base — needs a manual rebase"
            exit 4
        fi
        if [ "$review" = "CHANGES_REQUESTED" ]; then
            echo "PR #$pr: green but a reviewer requested changes"
            exit 4
        fi
        if [ "$review" = "REVIEW_REQUIRED" ]; then
            if [ "$auto" = "on" ]; then
                echo "PR #$pr: green but a required review is missing — auto-merge is armed and will land it once approved"
            else
                echo "PR #$pr: green but a required review is missing"
            fi
            exit 4
        fi

        # Behind the base. Auto-merge updates the branch itself only when the
        # repo allows it, so nudge it at most twice and let CI re-run.
        if [ "$merge_state" = "BEHIND" ] && [ "$update_branch" -eq 1 ] && [ "$updates_attempted" -lt 2 ]; then
            updates_attempted=$(( updates_attempted + 1 ))
            echo "  behind base — updating branch (attempt $updates_attempted/2)"
            gh pr update-branch "$pr" 2>&1 | sed 's/^/    /' || true
            sleep "$interval"
            continue
        fi

        # Nothing blocking and auto-merge is not armed: merge it directly.
        if [ "$auto" = "off" ] && [ "$merge_attempted" -eq 0 ]; then
            merge_attempted=1
            echo "  auto-merge not armed — merging with --$merge_method"
            if gh pr merge "$pr" "--$merge_method" 2>&1 | sed 's/^/    /'; then
                sleep 5
                continue
            fi
            echo "  direct merge refused — trying to arm auto-merge instead"
            gh pr merge "$pr" --auto "--$merge_method" 2>&1 | sed 's/^/    /' || true
            sleep "$interval"
            continue
        fi

        # Auto-merge armed (or merge already attempted): wait for GitHub.
        if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "PR #$pr: green but not merged within ${timeout_min}m (state=$merge_state) — timed out"
            exit 2
        fi
        echo "  waiting for the merge to land…"
        sleep "$interval"
        continue
    fi

    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "PR #$pr: still pending after ${timeout_min}m — timed out"
        exit 2
    fi
    sleep "$interval"
done
