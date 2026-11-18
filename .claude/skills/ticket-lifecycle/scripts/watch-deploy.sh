#!/usr/bin/env bash
# Wait until a merged commit is actually running on the testing host.
#
# testing.idclear.com is deployed by Coolify from `staging`: a host-side poller
# notices the new sha within ~60s and queues a deploy (see
# docs/coolify-testing-host.md). "Merged" therefore is not "deployed", and the
# public URL cannot tell you either — it sits behind Cloudflare Access and
# /healthz carries no version. So this asks Coolify itself, over SSH:
#
#   GET /api/v1/deployments/applications/<uuid>   → [{commit, status, …}]
#
# A deployment counts when its commit CONTAINS the merge commit (equal to it or
# a descendant on staging). The poller skips ticks while a deploy is in flight,
# so a busy morning often deploys our change inside someone else's later sha —
# that is still our change deployed. Then the origin's /healthz must answer 200.
#
# Usage:  watch-deploy.sh <merge-sha> [--interval 60] [--timeout-min 40]
# Env:    DEPLOY_SSH=targ@212.227.30.157
#
# Exit:   0 deployed and healthy (prints the deployment line)
#         1 the newest deployment containing the commit FAILED and nothing newer is queued
#         2 timed out (no deployment containing it finished in time)
#         3 SSH / Coolify API unreachable on every attempt
#         64 usage
set -uo pipefail

sha=""; interval=60; timeout_min=40
while [ $# -gt 0 ]; do
    case "$1" in
        --interval) interval="${2:?}"; shift 2 ;;
        --timeout-min) timeout_min="${2:?}"; shift 2 ;;
        -*) echo "unknown flag $1" >&2; exit 64 ;;
        *) sha="$1"; shift ;;
    esac
done
[ -n "$sha" ] || { sed -n '17,18p' "$0" >&2; exit 64; }

host="${DEPLOY_SSH:-targ@212.227.30.157}"
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=15)
deadline=$(( $(date +%s) + timeout_min * 60 ))

git fetch -q origin staging || true
sha="$(git rev-parse --verify "$sha^{commit}" 2>/dev/null)" || {
    echo "watch-deploy: $sha is not a commit known here (fetch origin staging?)" >&2; exit 64; }

# Logs are huge; strip them on the way out so only the summary crosses the wire
# when jq exists on the host, and locally otherwise.
fetch_deployments() {
    ssh "${ssh_opts[@]}" "$host" '
        T=$(sudo -n cat /root/coolify-api-token) && A=$(sudo -n cat /root/coolify-app-uuid) || exit 3
        curl -sf -H "Authorization: Bearer $T" "http://127.0.0.1:8000/api/v1/deployments/applications/$A?take=15"' |
    jq -c '[.deployments[] | {id, commit, status, created_at, updated_at}] | sort_by(.id) | reverse'
}

healthz() {
    ssh "${ssh_opts[@]}" "$host" \
        'curl -sk -o /dev/null -w "%{http_code}" -H "Host: testing.idclear.com" https://127.0.0.1/healthz'
}

contains() {  # does deployed commit $1 contain our sha?
    [[ "$1" =~ ^[0-9a-f]{40}$ ]] || return 1
    git cat-file -e "$1^{commit}" 2>/dev/null || git fetch -q origin staging || true
    git merge-base --is-ancestor "$sha" "$1" 2>/dev/null
}

echo "watch-deploy: waiting for ${sha:0:9} on $host (timeout ${timeout_min}m)"
fails=0; last=""
while :; do
    if ! deps="$(fetch_deployments)" || [ -z "$deps" ]; then
        fails=$((fails + 1))
        echo "watch-deploy: Coolify API unreachable (attempt $fails)" >&2
        [ "$fails" -ge 5 ] && exit 3
    else
        fails=0
        verdict=""; line=""
        busy="$(jq -r '[.[] | select(.status == "queued" or .status == "in_progress")] | length' <<<"$deps")"
        # Newest first: the first deployment containing our commit decides.
        while IFS=$'\t' read -r id commit status updated; do
            if contains "$commit"; then
                line="deployment #$id ${commit:0:9} $status ($updated)"
                case "$status" in
                    finished) verdict=ok ;;
                    failed|cancelled*) verdict=failed ;;
                    *) verdict=pending ;;
                esac
                break
            fi
        done < <(jq -r '.[] | [.id, (.commit // ""), .status, .updated_at] | @tsv' <<<"$deps")

        [ "$line" != "$last" ] && [ -n "$line" ] && echo "watch-deploy: $line"
        last="$line"

        case "$verdict" in
            ok)
                code="$(healthz || true)"
                if [ "$code" = 200 ]; then echo "DEPLOYED: $line, /healthz 200"; exit 0; fi
                echo "watch-deploy: deployed but /healthz answered '${code:-nothing}', rechecking" >&2 ;;
            failed)
                # A failed deploy is not retried by the poller; only a newer push
                # will carry our commit again. If nothing is in flight, say so.
                if [ "$busy" = 0 ]; then echo "FAILED: $line" >&2; exit 1; fi ;;
            *) [ -z "$line" ] && echo "watch-deploy: no deployment contains ${sha:0:9} yet ($busy in flight)" ;;
        esac
    fi
    [ "$(date +%s)" -ge "$deadline" ] && { echo "TIMEOUT: ${last:-no deployment contains ${sha:0:9}}" >&2; exit 2; }
    sleep "$interval"
done
