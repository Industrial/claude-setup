#!/usr/bin/env bash
# Ingest a GitHub issue into .tmp/tickets/<n>/ — body, comments, and every
# attachment fetched to disk so the agent can actually LOOK at the screenshots.
#
# Why a script and not inline ctx_shell: ctx_shell refuses commands that write
# files (curl -o, redirects), so the download has to live in a file that
# ctx_shell merely *runs*. That is the whole reason this exists.
#
# Usage:  bash .claude/skills/ticket-to-pr/scripts/ingest-ticket.sh <issue-number>
# Output: .tmp/tickets/<n>/{ticket.json,ticket.md,attachments.tsv,att-NN.<ext>}
#         plus a manifest on stdout — read that, then native-Read each image.
set -euo pipefail

issue="${1:?usage: ingest-ticket.sh <issue-number>}"
repo_root="$(git rev-parse --show-toplevel)"
out="$repo_root/.tmp/tickets/$issue"
mkdir -p "$out"

gh issue view "$issue" \
    --json number,title,state,url,author,labels,assignees,milestone,createdAt,updatedAt,body,comments \
    > "$out/ticket.json"

# --- readable transcript -----------------------------------------------------
jq -r '
  "# " + (.title // "(no title)"),
  "",
  "- issue: #\(.number)  state: \(.state)  url: \(.url)",
  "- author: \(.author.login // "?")  created: \(.createdAt)  updated: \(.updatedAt)",
  "- labels: \((.labels // []) | map(.name) | join(", ") | if . == "" then "(none)" else . end)",
  "- assignees: \((.assignees // []) | map(.login) | join(", ") | if . == "" then "(none)" else . end)",
  "- milestone: \(.milestone.title // "(none)")",
  "",
  "## Body",
  "",
  (.body // "(empty)"),
  "",
  "## Comments (\((.comments // []) | length))",
  "",
  ((.comments // [])[] |
     "### \(.author.login // "?") — \(.createdAt)\n\n\(.body // "")\n")
' "$out/ticket.json" > "$out/ticket.md"

# --- attachment URLs, with provenance ---------------------------------------
# Both shapes occur in this repo: markdown ![](url) in bodies and raw <img src>
# in comments. Legacy user-images.githubusercontent.com links still exist too.
jq -r '
  ([{src: "body", who: (.author.login // "?"), text: (.body // "")}]
   + ((.comments // [])[] | [{src: ("comment " + .createdAt), who: (.author.login // "?"), text: (.body // "")}]))
  | .[]
  | . as $s
  | ($s.text
     | [scan("https://(?:github\\.com/user-attachments/assets/[0-9a-zA-Z._-]+|user-images\\.githubusercontent\\.com/[0-9a-zA-Z._/-]+|github\\.com/[0-9a-zA-Z._-]+/[0-9a-zA-Z._-]+/assets/[0-9]+/[0-9a-zA-Z._-]+)")])
  | .[]
  | "\($s.src)\t\($s.who)\t\(.)"
' "$out/ticket.json" | awk -F'\t' '!seen[$3]++' > "$out/attachments.raw.tsv"

token="$(gh auth token)"
: > "$out/attachments.tsv"
printf 'file\tkind\tviewable\tfrom\tby\turl\n' >> "$out/attachments.tsv"

n=0
while IFS=$'\t' read -r src who url; do
    [ -n "${url:-}" ] || continue
    n=$((n + 1))
    stem="$(printf 'att-%02d' "$n")"
    tmp="$out/$stem.bin"
    if ! curl -fsSL -H "Authorization: token $token" -o "$tmp" "$url"; then
        printf '%s\tDOWNLOAD-FAILED\tno\t%s\t%s\t%s\n' "$stem" "$src" "$who" "$url" >> "$out/attachments.tsv"
        continue
    fi
    mime="$(file --mime-type -b "$tmp")"
    case "$mime" in
        image/png) ext=png; view=yes ;;
        image/jpeg) ext=jpg; view=yes ;;
        image/gif) ext=gif; view=yes ;;
        image/webp) ext=webp; view=yes ;;
        image/svg+xml) ext=svg; view=yes ;;
        application/pdf) ext=pdf; view=yes ;;
        video/*) ext="${mime#video/}"; view=no ;;
        text/*) ext=txt; view=no ;;
        *) ext=bin; view=no ;;
    esac
    mv "$tmp" "$out/$stem.$ext"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$stem.$ext" "$mime" "$view" "$src" "$who" "$url" >> "$out/attachments.tsv"
done < "$out/attachments.raw.tsv"

rm -f "$out/attachments.raw.tsv"

printf 'ingested #%s -> %s\n' "$issue" "${out#"$repo_root"/}"
printf '  ticket.md      %s lines\n' "$(wc -l < "$out/ticket.md")"
printf '  comments       %s\n' "$(jq -r '(.comments // []) | length' "$out/ticket.json")"
printf '  attachments    %s\n\n' "$n"
column -t -s$'\t' "$out/attachments.tsv" 2>/dev/null || cat "$out/attachments.tsv"
printf '\nviewable=yes files must be opened with the NATIVE Read tool (ctx_read has no vision path).\n'
