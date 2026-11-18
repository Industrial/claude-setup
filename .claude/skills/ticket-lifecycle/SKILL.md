---
name: ticket-lifecycle
description: >-
  Drive one ticket on the idclear project board (github.com/orgs/idclear/projects/4)
  from Ready to Staging unattended: move the card as work progresses, do the work in an
  auto-cleaned git worktree off staging (via ticket-to-pr), open the PR with auto-merge
  armed, comment the PR link on the ticket, wait for the merge, confirm the Coolify deploy
  on the testing host actually contains it, then move the card to Staging. Use when handed
  a ticket number with "run the lifecycle", "take #1234 from Ready to Staging", "work the
  board ticket 1234".
tags: [github, projects, board, delivery, deploy, worktree, autonomous]
---

# ticket-lifecycle — Ready → Staging, one ticket, unattended

This skill is the **board and environment wrapper** around `ticket-to-pr`. That skill owns
diagnosis, plan, implementation, tests, PR, auto-merge and the CI watch; read its `SKILL.md`
and follow it for those phases. This one adds what happens around them:

| Stage | Card moves to | Done when |
|---|---|---|
| 0 Preflight | — | token has `project` scope, card is in **Ready** |
| 1 Start | **In Progress** | worktree exists and is bootstrapped |
| 2 Work | — | `ticket-to-pr` Phases 0–4 pass inside the worktree |
| 3 PR | **In Review** | PR open, auto-merge armed, PR link commented on the ticket |
| 4 Merge | — | `watch-pr.sh` exits `0` |
| 5 Cleanup | — | worktree removed |
| 6 Deploy | **Staging** | `watch-deploy.sh` exits `0`, deploy comment posted |

Invoking this skill is the human gate for the whole run, exactly as for `ticket-to-pr`
(PROTOCOL rail 3, single pass). The ID rails still bind: mode declaration every reply.

## Paths and tooling

```bash
S=~/.claude/skills/ticket-lifecycle/scripts     # this skill
T=~/.claude/skills/ticket-to-pr/scripts         # reused: ingest-ticket.sh, watch-pr.sh
```

Every script needs `gh` and `jq`. `gh` is on PATH inside `devenv shell`, not outside it — run
the scripts as `devenv shell -- bash $S/<script> …` if `gh` is not found. Scripts write only
under `.tmp/` in the current checkout, so the write-path guard never fires.

Board defaults (override with env): `BOARD_OWNER=idclear BOARD_NUMBER=4 BOARD_FIELD=Status
BOARD_REPO=idclear/monorepo`. The columns are the options of the `Status` field. Names are
matched with case, spacing, punctuation and emoji ignored, and `move` takes `A|B|C`
alternatives, so a column renamed from "In review" to "👀 Review" is handled by the list
below rather than by editing the script.

| Logical stage | `board.sh move` argument |
|---|---|
| Ready (precondition) | `Ready|Todo|To do` |
| In Progress | `In Progress|Doing|WIP` |
| In Review | `In Review|Review|PR` |
| Staging | `Staging|On Staging|Deployed` |

`move` exits `3` when no column matches. For **In Progress** and **In Review** that is not a
failure — the board may not have that column; log it and continue. For **Staging** it is a
stop: run `board.sh columns`, report the real names, and hand back.

---

## Stage 0 — Preflight

```bash
bash $S/board.sh check              # exit 10 = no `project` scope → stop, see "Access" below
bash $S/board.sh status <n>         # must print the Ready column
gh issue view <n> --repo idclear/monorepo --json state,title,assignees
```

- Card not in **Ready** → stop and say where it is. Do not pull work from Backlog, and do not
  restart a ticket that is already In Progress unless the user said to (then reuse its
  worktree/branch — `worktree.sh open` does that).
- Issue closed → stop.
- Assign yourself: `gh issue edit <n> --repo idclear/monorepo --add-assignee @me`.

## Stage 1 — Start

```bash
bash $S/board.sh move <n> 'In Progress|Doing|WIP'
HOME_TREE=$(git rev-parse --show-toplevel)       # the checkout you started in; Stage 5 returns here
WT=$(bash $S/worktree.sh open <n> <slug> fix)     # feat|chore when that is the change
cd "$WT"
```

`<slug>` is 2–5 kebab-case words from the issue title. The worktree is created under
`.tmp/worktrees/gh-<n>` of the **current** checkout, on a new branch `<type>/gh-<n>-<slug>`
off `origin/staging` (an existing branch for the ticket is reused). `open` also initialises
any submodules. The devenv modules themselves are vendored under `nix/devenv-modules/`,
so `devenv` no longer depends on a submodule checkout.

Bootstrap once, from inside the worktree:

```bash
devenv shell -- bun install --frozen-lockfile
```

**From here until Stage 5, every command runs in `$WT`.** Re-`cd` if a shell resets.

## Stage 2 — Work (ticket-to-pr Phases 0–4)

Follow `ticket-to-pr` Phase 0 (ingest) through Phase 4 (review) verbatim, inside `$WT`, using
`$T/ingest-ticket.sh`. Its coverage leaf, stop conditions and three-red-rounds rule all apply.

One override: **skip ticket-to-pr Phase 5's `git switch -c`** — the worktree is already on the
ticket branch, based on `origin/staging`. If `origin/staging` moved while you worked,
`git fetch origin staging && git rebase origin/staging` before pushing.

## Stage 3 — PR, auto-merge, link it on the ticket

Commit, gate and push as in ticket-to-pr Phase 5, then:

```bash
gh pr create --base staging --title "<type>(<scope>): <summary> (GH-<n>)" \
  --body-file .tmp/tickets/<n>/pr-body.md
gh pr merge <pr> --auto --squash          # never --admin; refusals as in ticket-to-pr
```

The PR body references the ticket with **`Refs #<n>`, never `Closes`/`Fixes #<n>`**. A closing
keyword closes the issue on merge, and the board's built-in "Item closed" workflow then moves
the card to Done — skipping Staging and racing this skill. The ticket stays open; the reporter
closes it after retesting on testing.

Post the ticket comment immediately (ticket-to-pr Phase 6's five-part rundown; the PR link is
its first line), then move the card:

```bash
gh issue comment <n> --repo idclear/monorepo --body-file .tmp/tickets/<n>/ticket-comment.md
bash $S/board.sh move <n> 'In Review|Review|PR'
```

## Stage 4 — Wait for the merge

```bash
bash $T/watch-pr.sh <pr> --interval 30 --timeout-min 45
```

Run it in the background and poll; exit codes and what to do for each are in ticket-to-pr
Phase 7. Only exit `0` continues. Exit `4` (`REVIEW_REQUIRED` and friends) means auto-merge is
armed and a human has to act: report it, **leave the card in In Review**, keep the worktree,
and stop — re-invoking the skill later resumes at this stage.

On merge, capture the squash commit:

```bash
MERGE_SHA=$(gh pr view <pr> --json mergeCommit --jq .mergeCommit.oid)
```

## Stage 5 — Clean up the worktree

The code is on `staging`; the worktree has no further purpose. Leave it before removing it:

```bash
cd "$HOME_TREE"        # not the main repo: the worktree lives under THIS checkout's .tmp/
bash $S/worktree.sh close <n>
```

`close` refuses (exit `1`) on uncommitted changes, or commits not on the remote that are not
on staging either — that is unpushed work, so report it rather than forcing. It never deletes
a branch; GitHub's delete-on-merge handles the remote one and the guard hook forbids local
deletion. `worktree.sh gc` sweeps every ticket worktree whose PR is merged — run it at the end
of a session that ran several tickets, or after a crashed run.

The worktree is also cleaned on a stop **after** the merge. On a stop **before** the merge it is
kept on purpose: it holds the work a human needs to look at.

## Stage 6 — Confirm the deploy, then Staging

`staging` deploys to `https://testing.idclear.com` through Coolify, triggered by a host-side
poller within ~60s of the push (`docs/coolify-testing-host.md`). Merged is not deployed, and
the public URL cannot say which version runs (Cloudflare Access, versionless `/healthz`), so:

```bash
bash $S/watch-deploy.sh "$MERGE_SHA" --interval 60 --timeout-min 40
```

It asks the Coolify API on the host over SSH (`targ@212.227.30.157`, `DEPLOY_SSH` overrides)
which deployments exist, and succeeds when the newest one whose commit **contains** the merge
commit has `finished` and the origin `/healthz` answers 200. A later sha that includes ours
counts — the poller skips ticks while a deploy is in flight.

| Exit | Meaning | What you do |
|---|---|---|
| `0` | Deployed and healthy | Move to Staging, comment, finish |
| `1` | The deploy containing it **failed**, nothing newer queued | Stop. Comment on the PR (not the ticket) with the deployment id; leave the card in In Review. The poller does not retry failures — a human redeploys or fixes forward |
| `2` | Timed out | Re-arm once; second timeout → hand back with the last line it printed |
| `3` | SSH / API unreachable | Stop; the host, key or sudo is the problem, not the change |

On `0`:

```bash
bash $S/board.sh move <n> 'Staging|On Staging|Deployed'
gh issue comment <n> --repo idclear/monorepo --body "Deployed to https://testing.idclear.com in \`${MERGE_SHA:0:9}\` (PR #<pr>). Ready to retest there."
```

Then report: ticket, PR, merge sha, the deployment line, the board move, and any assumption
from the rundown still awaiting the reporter. **Do not close the ticket.**

---

## Access — why Stage 0 can fail with exit 10

GitHub Projects (v2) is only reachable with the classic OAuth scope `project` (`read:project`
to read). The default `gh auth login` grants `repo, read:org, gist` and not that, so the API
answers `INSUFFICIENT_SCOPES`. One-time fix, by a human, in a terminal:

```bash
gh auth refresh -h github.com -s project      # browser device flow; keeps existing scopes
gh auth status                                 # Token scopes now include 'project'
```

The account also needs **Write** (or Admin) on project 4 itself — org membership alone gives
Read on org projects by default. Project → ⋯ → Settings → Manage access.

For an unattended host (CI, Paperclip, a cron agent) use a fine-grained PAT owned by the
**idclear org** instead: Organization permissions → *Projects: Read and write*; Repository
permissions on `idclear/monorepo` → *Contents, Issues, Pull requests: Read and write*,
*Actions, Checks: Read*. Export it as `GH_TOKEN`. Org admins may need to approve it under
Settings → Personal access tokens.

## Stop and ask the human

Everything in ticket-to-pr's list, plus:

- `board.sh check` exits `10` — the token cannot see the board.
- The card is not in Ready at Stage 0.
- No column matches Staging.
- `watch-pr.sh` exits `4` or `5`, or `watch-deploy.sh` exits `1`, `3`, or `2` twice.
- `worktree.sh close` refuses.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `gh: command not found` | outside devenv | `devenv shell -- bash $S/…` |
| `devenv.nix file does not exist` in the worktree | worktree branch predates the vendored `nix/devenv-modules/`, or a submodule is not initialised | rebase onto current `origin/staging`; `git -C "$WT" submodule update --init --recursive` (`open` does this) |
| Card jumped to Done on merge | PR said `Closes #n` | use `Refs #n`; move the card back to Staging after the deploy |
| `move` exit 3 on In Progress / In Review | board has no such column | log it and carry on |
| `watch-deploy` sits at "no deployment contains …" | poller skipped (deploy in flight) or timer stopped | `ssh targ@… systemctl status coolify-staging-poller.timer` — report, do not trigger deploys yourself |
| `watch-deploy` exit 3 | `sudo -n` or SSH key not available to this session | hand back; never prompt for credentials |
