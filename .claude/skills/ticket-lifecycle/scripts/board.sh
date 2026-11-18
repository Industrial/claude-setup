#!/usr/bin/env bash
# Read and move a ticket's card on the org's GitHub Projects (v2) board.
#
# The board is a ProjectV2; its columns are the options of the single-select
# "Status" field. Moving a card means setting that field's value on the issue's
# project item — there is no "column" object in the API.
#
# Needs a token with the `project` scope (read:project is enough for `check`,
# `columns` and `status`). `gh auth status` shows the scopes; grant them with
#     gh auth refresh -h github.com -s project
#
# Usage:
#   board.sh check                       scopes + board metadata, or exit 10
#   board.sh columns                     every Status option, one per line
#   board.sh status <issue>              the issue's current column ("" if not on the board)
#   board.sh move   <issue> <name>[|<alt>...]
#                                        set the column; the first option whose
#                                        normalised name matches any alternative wins.
#                                        Adds the issue to the board if it is not on it.
#
# Env (defaults are idclear's board):
#   BOARD_OWNER=idclear  BOARD_NUMBER=4  BOARD_FIELD=Status  BOARD_REPO=idclear/monorepo
#
# Exit: 0 ok · 3 no option matched the requested column · 10 token lacks the
#       project scope · 64 usage · anything else is gh/GraphQL failing.
set -euo pipefail

owner="${BOARD_OWNER:-idclear}"
number="${BOARD_NUMBER:-4}"
field="${BOARD_FIELD:-Status}"
repo="${BOARD_REPO:-idclear/monorepo}"

die() { echo "board.sh: $1" >&2; exit "${2:-1}"; }
usage() { sed -n '12,25p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

# Lower-case and strip everything that is not a letter or digit, so
# "🚀 In Progress", "in-progress" and "In progress" all compare equal.
norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'; }

# Run a gh call; turn a missing scope into one clear instruction instead of
# three paragraphs of GraphQL error.
gql() {
    local out
    if ! out="$(gh api graphql "$@" 2>&1)"; then
        if grep -q -E 'INSUFFICIENT_SCOPES|read:project|required scopes' <<<"$out"; then
            die "token lacks the 'project' scope. Run: gh auth refresh -h github.com -s project" 10
        fi
        printf '%s\n' "$out" >&2
        exit 1
    fi
    printf '%s\n' "$out"
}

meta() {
    gql -F num="$number" -f org="$owner" -f fld="$field" -f query='
      query($org:String!,$num:Int!,$fld:String!){
        organization(login:$org){ projectV2(number:$num){
          id title url
          field(name:$fld){ ... on ProjectV2SingleSelectField { id name options { id name } } }
        } }
      }' --jq '.data.organization.projectV2'
}

# The issue's node id, and its item on THIS board if it has one.
issue_item() {
    gql -f owner="${repo%%/*}" -f name="${repo##*/}" -F n="$1" -f fld="$field" -f query='
      query($owner:String!,$name:String!,$n:Int!,$fld:String!){
        repository(owner:$owner,name:$name){ issue(number:$n){
          id title url state
          projectItems(first:50){ nodes{
            id
            project{ number owner{ ... on Organization{ login } ... on User{ login } } }
            fieldValueByName(name:$fld){ ... on ProjectV2ItemFieldSingleSelectValue{ name optionId } }
          } }
        } }
      }' --jq '.data.repository.issue' |
    jq --arg o "$owner" --argjson num "$number" '
      { id, title, url, state,
        item: ([.projectItems.nodes[] | select(.project.number == $num and .project.owner.login == $o)] | first) }'
}

cmd="${1:-}"; shift || true
case "$cmd" in
    check)
        gh auth status 2>&1 | grep -E 'Logged in|Active account|Token scopes' >&2 || true
        m="$(meta)"
        [ -n "$(jq -r '.field.id // empty' <<<"$m")" ] ||
            die "board $owner/$number has no single-select field named '$field'"
        jq -r '"board:   \(.title)  \(.url)", "field:   \(.field.name)",
               "columns: \([.field.options[].name] | join(" → "))"' <<<"$m"
        ;;
    columns)
        meta | jq -r '.field.options[].name'
        ;;
    status)
        [ $# -ge 1 ] || usage
        issue_item "$1" | jq -r '.item.fieldValueByName.name // ""'
        ;;
    move)
        [ $# -ge 2 ] || usage
        n="$1"; want="$2"
        m="$(meta)"
        project_id="$(jq -r .id <<<"$m")"
        field_id="$(jq -r .field.id <<<"$m")"

        option_id=""; option_name=""
        IFS='|' read -r -a alts <<<"$want"
        for alt in "${alts[@]}"; do
            while IFS=$'\t' read -r oid oname; do
                if [ "$(norm "$oname")" = "$(norm "$alt")" ]; then
                    option_id="$oid"; option_name="$oname"; break 2
                fi
            done < <(jq -r '.field.options[] | [.id, .name] | @tsv' <<<"$m")
        done
        if [ -z "$option_id" ]; then
            echo "board.sh: no column matches '$want'. Columns: $(jq -r '[.field.options[].name] | join(", ")' <<<"$m")" >&2
            exit 3
        fi

        info="$(issue_item "$n")"
        item_id="$(jq -r '.item.id // empty' <<<"$info")"
        from="$(jq -r '.item.fieldValueByName.name // "(none)"' <<<"$info")"
        if [ -z "$item_id" ]; then
            item_id="$(gql -f p="$project_id" -f c="$(jq -r .id <<<"$info")" -f query='
              mutation($p:ID!,$c:ID!){ addProjectV2ItemById(input:{projectId:$p,contentId:$c}){ item{ id } } }' \
              --jq '.data.addProjectV2ItemById.item.id')"
            echo "board.sh: #$n was not on the board; added it" >&2
        fi

        gql -f p="$project_id" -f i="$item_id" -f f="$field_id" -f o="$option_id" -f query='
          mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){
            updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){
              projectV2Item{ id } } }' >/dev/null
        echo "#$n: $from → $option_name"
        ;;
    *) usage ;;
esac
