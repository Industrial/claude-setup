---
name: ticket-lifecycle
description: >-
  Drive one ticket on the idclear project board (github.com/orgs/idclear/projects/4)
  from Ready to Staging unattended: move the card as work progresses, do the work in an
  auto-cleaned, light git worktree off staging (no install, no local gates: the PR's CI is
  the gate, via ticket-to-pr), open the PR with auto-merge
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
| 1 Start | **In Progress** | a light worktree exists (no install, no gates) |
| 2 Work | — | `ticket-to-pr` Phases 0–4 done inside the worktree, minus its local gates |
| 3 PR | **In Review** | PR open, auto-merge armed, PR link commented on the ticket |
| 4 Merge | — | `watch-pr.sh` exits `0`: the PR's CI is the quality gate |
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

### Worktrees are light: CI is the gate

A ticket worktree is a **checkout and nothing more**. No `bun install`, no `devenv shell`,
no local lint, typecheck, test or coverage run inside it. The PR's CI runs every one of those
gates, and Stage 4 waits on that CI. This keeps a worktree to a few seconds and a few
megabytes, so many tickets can run side by side. Three rules follow from it:

1. **Never enter `devenv shell` inside a worktree.** Entry re-installs the shared prek
   hooks with `--config=<that worktree>/…`, which breaks every commit in every checkout
   once the worktree is gone. Run `git` natively in the worktree. Run `gh` and this
   skill's scripts from the **main checkout's** devenv, which every command here supports:
   `(cd "$HOME_TREE" && devenv shell -- gh pr create --repo idclear/monorepo --head <branch> …)`.
2. **Commit and push with `--no-verify`.** The hooks in `.git/hooks` are shared by every
   worktree, and they run `moon :lint :test`/`:coverage` against the worktree, which has
   no `node_modules`. They would fail on the missing install, not on the change. Skipping
   them is safe here only because the PR's CI runs the same gates. Never use
   `--no-verify` outside a light worktree.
3. **Read and edit code only.** Static tools that need no install still help: `git diff`,
   `git grep`, and reading neighbouring tests. Anything that needs `node_modules` (a test
   run, `tsgo`, biome, oxlint) is CI's job. When you need to know whether a change type-checks
   or a test passes, push and read the CI log. Do not install to find out.

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

- Card not in **Ready** → stop and say where it is. Do not pull work from Backlog on your own
  initiative, and do not restart a ticket that is already In Progress unless the user said to
  (then reuse its worktree/branch — `worktree.sh open` does that). When the user names the
  tickets explicitly ("work #1822–1834"), that *is* the pull: move each through
  `board.sh move <n> Ready` as you start it, and say so once.
- The ticket asks for a design choice rather than a fix (a "to discuss with …" marker, "to be
  decided", competing options in the comments) → do not build a guess. Comment the specific
  decisions needed, numbered so they can be answered inline, leave the card where it is, and
  move on to the next ticket.
- Issue closed → stop.
- Assign yourself: `gh issue edit <n> --repo idclear/monorepo --add-assignee @me`.
- **Rework.** A card back in Ready after it was in Staging (the business team drags tickets
  back to Ready when testing found more to do) is rework, not a fresh ticket. The comments
  after the last deploy comment are the new requirement. Read them first, and treat the
  earlier PR as what was already tried. `worktree.sh open` sees the old branch's PR merged
  and cuts a fresh branch off current staging, so the rework never builds on stale history.
  To list what came back: `.tmp/status-history.sh`-style timeline queries for
  `PROJECT_V2_ITEM_STATUS_CHANGED_EVENT` with `previousStatus: Staging`.

## Stage 1 — Start

```bash
bash $S/board.sh move <n> 'In Progress|Doing|WIP'
HOME_TREE=$(git rev-parse --show-toplevel)       # the checkout you started in; Stage 5 returns here
WT=$(bash $S/worktree.sh open <n> <slug> fix)     # feat|chore when that is the change
cd "$WT"
```

`<slug>` is 2–5 kebab-case words from the issue title. The worktree is created under
`.tmp/worktrees/gh-<n>` of the **current** checkout, on a new branch `<type>/gh-<n>-<slug>`
off `origin/staging` (an existing branch for the ticket is reused).

There is **no bootstrap step**. `open` leaves submodules uninitialised: the code never needs
`.claude-setup`, and `nix/devenv-modules/` is vendored. Pass `--submodules` only if the ticket
edits a submodule. Do not run `bun install`. See "Worktrees are light" above.

**From here until Stage 5, `git` and file edits run in `$WT`. `gh` and the scripts run from
`$HOME_TREE`'s devenv** (rule 1 above). Re-`cd` if a shell resets.

## Stage 2 — Work (ticket-to-pr Phases 0–4)

Follow `ticket-to-pr` Phase 0 (ingest) through Phase 4 (review) inside `$WT`, using
`$T/ingest-ticket.sh` (run from `$HOME_TREE`: it needs `gh`). Its coverage leaf, stop
conditions and three-red-rounds rule all apply.

Overrides, all following from light worktrees:

- **No local gates.** Skip ticket-to-pr Phase 3's per-leaf gate commands (`oxlint`,
  `typecheck`, `moon run :test`) and Phase 5's `ci:pre-push`. The PR's CI runs them; Stage 4
  is where you find out.
- **The coverage leaf is still mandatory:** write the test that witnesses the fix. You cannot
  watch it fail locally, so state in the PR body why it fails on `origin/staging` (the
  assertion and the line it contradicts). CI shows it passing with the fix.
- **Review is a reading pass.** Phase 4's lenses read the diff. They do not run gates.
- **Skip Phase 5's `git switch -c`.** The worktree is already on the ticket branch, based on
  `origin/staging`. If `origin/staging` moved while you worked,
  `git fetch origin staging && git rebase origin/staging` before pushing.

## Stage 3 — PR, auto-merge, link it on the ticket

Commit and push from `$WT` without running hooks (rule 2), then open the PR from
`$HOME_TREE`:

```bash
git -C "$WT" commit --no-verify -F .tmp/tickets/<n>/commit-msg.txt     # message shape: ticket-to-pr Phase 5
git -C "$WT" push --no-verify -u origin <type>/gh-<n>-<slug>
cd "$HOME_TREE"
devenv shell -- gh pr create --repo idclear/monorepo --base staging --head <type>/gh-<n>-<slug> \
  --title "<type>(<scope>): <summary> (GH-<n>)" --body-file .tmp/tickets/<n>/pr-body.md
devenv shell -- gh pr merge <pr> --repo idclear/monorepo --auto --squash   # never --admin
```

Write the commit message to a file rather than a heredoc: the shell guard reads words such
as "find" inside a quoted message as commands.

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
Phase 7. Only exit `0` continues.

**This watch is the quality gate.** Every lint, type, test and coverage failure surfaces here
first, because nothing ran locally. On exit `1`, read `.tmp/ci/pr-<pr>-run-<id>.log`, fix in
`$WT`, commit and push with `--no-verify`, and re-arm the watcher. Each push counts toward
ticket-to-pr's three-red-rounds limit. A red check that also fails on `staging` is not
yours: say so in the PR and do not chase it. Exit `4` (`REVIEW_REQUIRED` and friends) means auto-merge is
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

## Many tickets at once

Light worktrees exist to make this cheap: one subagent per ticket, each in its own
`.tmp/worktrees/gh-<n>`, all running Stages 0–6 concurrently.

- **The orchestrator does the board work first, serially:** preflight (`board.sh check`
  once), assignment, and the Ready-column triage. It skips tickets assigned to someone
  else unless told otherwise. Each subagent then owns exactly one ticket, its worktree and
  its PR. Two agents never share a worktree.
- **Brief each subagent with the light-worktree rules verbatim** (no install, no
  `devenv shell` in the worktree, `--no-verify`, `gh` from the main checkout). A subagent
  that installs or gates locally defeats the point and races the others for memory.
- **Overlapping tickets** (same files, same step or screen) go to one agent, sequentially,
  or the second PR is cut after the first merges. Otherwise both rebase-conflict at merge time.
- **Deploys are shared.** Every merge to staging triggers one Coolify deploy, and the poller
  skips ticks while one runs, so a later deploy can contain several tickets.
  `watch-deploy.sh` accepts any finished deployment that *contains* the merge commit. Let
  each agent run its own Stage 6, or have the orchestrator watch the last merge once and move
  every card it contains.
- **Stop conditions stay per ticket.** One ticket stopping for a human (a design decision,
  watcher exit `4`) does not stop the others.
- Finish with `worktree.sh gc` from the main checkout.

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
| `gh: command not found` | outside devenv | `devenv shell -- bash $S/…`, or `nix shell nixpkgs#gh --command …` where devenv cannot evaluate |
| `devenv.nix file does not exist` in the worktree | worktree branch predates the vendored `nix/devenv-modules/`, or a submodule is not initialised | rebase onto current `origin/staging`; `git -C "$WT" submodule update --init --recursive` (`open` does this) |
| Entering devenv modified a file you never touched | `devenv:git-hooks:run` runs the pre-commit formatter over the whole tree on every entry | `git checkout -- <file>` before committing — unless `format:check` fails on base too, in which case that file blocks every PR: carry the format fix as its own `style:` commit and say why in the PR |
| Commit fails "Stashed changes conflicted with changes made by hook" | same formatter rewrote an unstaged file | as above |
| Every commit/push in every checkout fails after cleanup | devenv entry in the worktree re-installed the shared prek hooks with `--config=<worktree>/…` | `worktree.sh close` repoints them at the main checkout; for a worktree removed by hand, `sed -i 's#<wt>/#<main>/#' "$(git rev-parse --git-common-dir)"/hooks/*` |
| A unit test of the reader passes, the bug persists | the step never receives the cell — `display.values` carries only the step's *own* declared cells | the regression test must go through the step builder and the controller's prefill functions, not hand the reader the row |
| A watcher "succeeded" but the PR is still open or the deploy unconfirmed | its output was piped (`… \| tail`), so the exit code you saw is `tail`'s | redirect to a log and `echo "exit=$?"` instead; the exit-code tables above only hold for the script's own code |
| `test` red after ~45 min with no failed step; annotation "The hosted runner lost communication with the server" | GitHub runner died (resource starvation), not a test failure | `gh run rerun <run-id> --failed` once and re-arm the watcher; it counts toward the three-red-rounds limit only if it recurs |
| Card jumped to Done on merge | PR said `Closes #n` | use `Refs #n`; move the card back to Staging after the deploy |
| `move` exit 3 on In Progress / In Review | board has no such column | log it and carry on |
| `watch-deploy` sits at "no deployment contains …" | poller skipped (deploy in flight) or timer stopped | `ssh targ@… systemctl status coolify-staging-poller.timer` — report, do not trigger deploys yourself |
| `watch-deploy` exit 3 | `sudo -n` or SSH key not available to this session | hand back; never prompt for credentials |
