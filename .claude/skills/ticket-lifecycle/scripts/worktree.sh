#!/usr/bin/env bash
# One git worktree per ticket, under the current checkout's gitignored .tmp/,
# created off origin/staging and removed again once the work has landed.
#
# The worktree lives INSIDE the working tree on purpose: the write-path guard
# refuses writes outside it, and .tmp/ is already gitignored.
#
# Usage:
#   worktree.sh open  <issue> <slug> [fix|feat|chore]   print the worktree path
#   worktree.sh path  <issue>                           print it if it exists
#   worktree.sh close <issue> [--force]                 remove it (never the branch)
#   worktree.sh gc                                      close every ticket worktree whose PR is merged
#
# `open` is idempotent: an existing worktree for the ticket is reused, and an
# existing local or remote branch is checked out rather than recreated.
#
# `close` refuses while the worktree has uncommitted changes or commits that
# are not on the remote branch — losing unpushed work is the one way cleanup
# can hurt. --force overrides that. Branches are never deleted (the guard hook
# forbids it, and GitHub's delete-on-merge already handles the remote one).
#
# Exit: 0 ok · 1 refused (dirty / unpushed) · 2 no worktree · 64 usage.
set -euo pipefail

usage() { sed -n '7,12p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

top="$(git rev-parse --show-toplevel)"
base="$top/.tmp/worktrees"
wt_for() { printf '%s/gh-%s' "$base" "$1"; }

close_one() {
    local wt="$1" force="$2"
    [ -d "$wt" ] || { echo "worktree.sh: no worktree at $wt" >&2; return 2; }
    if [ "$force" != 1 ]; then
        if [ -n "$(git -C "$wt" status --porcelain --ignore-submodules=all)" ]; then
            echo "worktree.sh: $wt has uncommitted changes; refusing (use --force)" >&2; return 1
        fi
        local up
        if up="$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
            git -C "$wt" fetch -q origin "${up#origin/}" 2>/dev/null || true
            if [ -n "$(git -C "$wt" log --oneline '@{u}..HEAD' 2>/dev/null)" ]; then
                # Commits not on the branch may still be on staging (squash-merged
                # and the remote branch deleted) — only refuse if staging lacks the tree.
                if ! git -C "$wt" diff --quiet origin/staging HEAD -- 2>/dev/null; then
                    echo "worktree.sh: $wt has commits not on $up; refusing (use --force)" >&2; return 1
                fi
            fi
        fi
    fi
    git worktree remove --force "$wt"
    git worktree prune
    repoint_hooks "$wt"
    echo "removed $wt"
}

# Entering `devenv shell` in a worktree re-installs the repo's prek hooks with
# `--config=<that worktree>/.pre-commit-config.yaml`, and the hooks directory is
# shared by every worktree. Once the worktree is gone every commit and push in
# every checkout would fail on a missing config — so point any hook that names
# the removed tree back at the main checkout's config.
repoint_hooks() {
    local gone="$1" hooks main
    hooks="$(git rev-parse --path-format=absolute --git-common-dir)/hooks"
    main="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
    for h in "$hooks"/*; do
        [ -f "$h" ] || continue
        if grep -qF "$gone/" "$h"; then
            sed -i "s#$gone/#$main/#g" "$h"
            echo "repointed $(basename "$h") hook at $main" >&2
        fi
    done
}

cmd="${1:-}"; shift || true
case "$cmd" in
    open)
        [ $# -ge 2 ] || usage
        n="$1"; slug="$2"; type="${3:-fix}"
        case "$type" in fix|feat|chore) ;; *) usage ;; esac
        wt="$(wt_for "$n")"
        if [ -d "$wt" ]; then echo "$wt"; exit 0; fi

        mkdir -p "$base"
        git fetch -q origin staging
        # Reuse a branch already started for this ticket, local or remote.
        existing="$(git for-each-ref --format='%(refname:short)' "refs/heads/*/gh-$n-*" | head -n1)"
        remote="$(git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/*/gh-$n-*" | head -n1)"
        if [ -n "$existing" ]; then
            git worktree add -q "$wt" "$existing" >&2
        elif [ -n "$remote" ]; then
            git worktree add -q --track -b "$remote" "$wt" "origin/$remote" >&2
        else
            git worktree add -q --no-track -b "$type/gh-$n-$slug" "$wt" origin/staging >&2
        fi
        # A fresh worktree has no submodules; initialise them so submodule-backed
        # paths resolve. (The devenv modules are vendored under nix/devenv-modules/.)
        git -C "$wt" submodule update --init --recursive -q >&2
        echo "$wt"
        ;;
    path)
        [ $# -ge 1 ] || usage
        wt="$(wt_for "$1")"; [ -d "$wt" ] || exit 2; echo "$wt"
        ;;
    close)
        [ $# -ge 1 ] || usage
        force=0; [ "${2:-}" = "--force" ] && force=1
        close_one "$(wt_for "$1")" "$force"
        ;;
    gc)
        [ -d "$base" ] || exit 0
        for wt in "$base"/gh-*; do
            [ -d "$wt" ] || continue
            branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
            state="$(gh pr view "$branch" --json state --jq .state 2>/dev/null || true)"
            if [ "$state" = "MERGED" ]; then close_one "$wt" 0 || true
            else echo "kept $wt ($branch: ${state:-no PR})"; fi
        done
        ;;
    *) usage ;;
esac
