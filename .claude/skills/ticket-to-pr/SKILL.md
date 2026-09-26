---
name: ticket-to-pr
description: >-
  Take one GitHub ticket all the way to a green PR without stopping for approval:
  ingest the issue body, comments and screenshots, diagnose it, plan it through
  /skills + /quality + /id, self-approve and execute every part of the plan, branch
  off staging, commit, push, open the PR, post a rundown comment linking the PR on
  the ticket, then watch CI and fix until it is green. Use when handed an issue number,
  an issue URL, or "work GH-1426", "take this ticket to a PR", "fix ticket 1234 end to end".
tags: [github, issues, delivery, ci, id-workflow, autonomous]
---

# ticket-to-pr — one ticket, one green PR, no hand-holding

## What invoking this skill means

Invoking it **is** the human gate. ID PROTOCOL rail 3 ("do not enter EXECUTE until the user
approves the plan") is satisfied by the invocation itself: this is the `plan+implement in one
pass` case the rail carves out. Say so once when you self-approve, then keep moving. Do not
stop to ask "shall I proceed?" between phases.

Everything else in the rails still binds: declare `[ID:<MODE>] lane:<lane>` on the first line of
every reply, advance modes explicitly, satisfy each exit checklist, Maestro is the only tracker.

Hand back to the human only for the stop conditions at the bottom. Nothing else.

## Harness constraints that shape every command here

| Need | Use | Never |
|---|---|---|
| Run anything | `ctx_shell` | native `Bash` (hook-denied) |
| Read code | `ctx_read` / `ctx_search` / `ctx_compose` | native `Read` / `Grep` |
| **Look at a screenshot** | **native `Read` on the `.png`/`.jpg`/`.pdf` path** | `ctx_read` — it has no vision path |
| Write or edit a file | `ctx_patch` (`op=create` / `op=replace_unique`) | native `Write` / `Edit` (hook-denied) |
| Download an attachment | the scripts below | inline `curl -o` in `ctx_shell` (guard-denied) |
| Scratch files | `.tmp/` in the working tree | `/tmp/claude-*` (guard-denied) |

`ctx_shell` refuses commands that write files, which is exactly why the two helpers in
`scripts/` exist: it will happily *run* a script that writes.

Mode changes: `bash plugins/id-workflow/hooks/id-state.sh set <MODE> --lane <lane>`.
The Stop hook runs `bun run oxlint` + `bun run typecheck` on changed TS before any turn can end —
budget for it rather than being surprised by it.

---

## Phase 0 — Ingest (ORIENT)

```bash
bash .claude/skills/ticket-to-pr/scripts/ingest-ticket.sh <issue-number>
```

Writes `.tmp/tickets/<n>/`: `ticket.json`, `ticket.md` (body + every comment in order),
`attachments.tsv` (provenance manifest), and every attachment on disk as `att-NN.<ext>`.

Then:

1. `ctx_read` `.tmp/tickets/<n>/ticket.md` — the whole conversation, not just the body. Tickets
   here are refined in the comments; the last comment usually carries the real requirement and
   supersedes the template body.
2. Native-`Read` the attachments that carry signal — the ones the newest comments point at, and
   any the text refers to ("see screenshot"). Cap it around ten; a long ticket can have 25 and
   reading all of them buys nothing. Screenshots in this repo are usually annotated in red — the
   circle *is* the bug report.
3. Follow cross-references: any `#1234` in body or comments, plus linked PRs
   (`gh issue view <n> --json ...` or `gh pr list --search <n>`). A prior PR against the same
   ticket tells you what was already tried.
4. `/skills` — list **reviewed** vs **using** by path. `/quality` — restate the ask in its
   sharpest correct form, naming the surfaces in play (app, feature folder, entity).
5. Set the lane: one file / one module → `tiny`; single-PR feature or bug fix → `normal`;
   migrations, cross-app, public API → `heavy`. `devenv shell -- maestro intake --paths <paths>`
   once paths are known.

Exit ORIENT with: sharp ask, named files, lane, and the ticket's acceptance behaviour in one
sentence — *what the reporter will click to check you fixed it*.

## Phase 1 — Diagnose (RESEARCH)

`id-state.sh set RESEARCH`. Read-only. `ctx_compose` first, then `roam_context` / `roam_uses` /
`roam_trace` on the symbols the ticket implicates.

Produce: the phenomenon, the ranked hypotheses, the cheapest disproof for each, and the
current behaviour of the code you believe is at fault — quoted, with `path:line`. A ticket
screenshot showing a wrong number is not a diagnosis until you can point at the line that
computes it.

Where the ticket's expected behaviour is genuinely unstated (the bug-report template left
unfilled is common here), derive it from the comments, state it as an explicit assumption, and
carry that sentence verbatim into the plan, the PR body and the ticket comment. Do not stall on
it, and do not silently pick one.

## Phase 2 — Plan (PLAN)

`id-state.sh set PLAN`. Writes limited to `.maestro/**`, `.cursor/plans/**`, `.tmp/**`.

- `tiny`: inline plan — leaves, files, AC per leaf. No mission.
- `normal`: light Maestro task from the ticket (`maestro_task_from_spec`), AC drawn from the
  ticket's acceptance behaviour, contract listing the paths you will touch.
- `heavy`: `/plan-hierarchically`, mission + execution overlay, then continue.

Every leaf needs: paths, acceptance criterion, and the gate that proves it. A leaf whose AC is
"code looks right" is not a leaf. Include a test leaf — this repo expects a regression witness
for a bug fix (see the `test(e2e): regression witness…` precedent in the log).

## Phase 3 — Self-approve and execute (EXECUTE)

State the approval explicitly, once:

> Plan approved under `ticket-to-pr` (invocation = human gate, PROTOCOL rail 3 single-pass).

`id-state.sh set EXECUTE`. Then, per leaf:

1. Claim on the **current branch**: `devenv shell -- maestro task claim <tsk-id> --skip-worktree`
   — CLI only, never MCP `maestro_task_claim`, which creates worktrees.
2. Implement contracted paths only via `ctx_patch`. Amend the contract if scope legitimately
   grows; do not smuggle drive-by refactors past it.
3. Gate and record evidence: `bun run oxlint`, `bun run typecheck`,
   `moon run :test --affected --cache off`, or
   `devenv shell -- definitively run .definitively/programs/pre-commit.yml`.

Execute **all** leaves. Partial delivery is a stop condition, not a milestone.

## Phase 4 — Review (REVIEW)

`id-state.sh set REVIEW`. Evidence-only writes. Falsify the diff against the ticket's acceptance
behaviour, not against your plan — the plan can be wrong in the same way the implementation is.
Fan out `id-review-lens` (ac, correctness, scope, tests) when the diff is more than a couple of
files. FAIL → back to EXECUTE with a concrete fix list. PASS → SHIP.

## Phase 5 — Branch, commit, push, PR (SHIP)

`id-state.sh set SHIP`. Branch off `staging` — the default branch of `idclear/monorepo` is
`staging`, never `main`:

```bash
git fetch origin staging
git switch -c fix/gh-<n>-<slug> origin/staging     # feat/ or chore/ when that is the change
```

If the ticket branch already exists and is checked out, stay on it and rebase onto
`origin/staging` rather than making a second branch. **Never delete a branch** — the guard hook
blocks `git branch -d/-D` and `git push --delete` outright, and that rule is not bypassable.

Commit in the repo's shape — `type(scope): summary (GH-<n>)`, body explaining the *why*, then
the trailers this repo uses (`Refs #<n>`, `Claude-Session:`, `Co-authored-by:`).

Gate before pushing: `bun run ci:pre-push` (lint + affected tests + coverage vs remote), or
`devenv shell -- definitively run .definitively/programs/pre-push.yml`.

```bash
git push -u origin fix/gh-<n>-<slug>
```

Write the PR body with `ctx_patch op=create` to `.tmp/tickets/<n>/pr-body.md` — prose first
(product ruling, what changed, what is deliberately untouched), then `Refs #<n>` — and open it:

```bash
gh pr create --base staging --title "fix(scope): summary (GH-<n>)" \
  --body-file .tmp/tickets/<n>/pr-body.md
```

## Phase 6 — Report back on the ticket

Write `.tmp/tickets/<n>/ticket-comment.md` (`ctx_patch op=create`), then:

```bash
gh issue comment <n> --body-file .tmp/tickets/<n>/ticket-comment.md
```

The rundown is for the reporter, who is not an engineer. Five parts, short:

1. **PR** — the link.
2. **Diagnosis** — what was actually wrong, in their vocabulary, referencing their screenshot.
3. **Change** — what now happens instead, and which surfaces it touches.
4. **Assumptions** — every expected-behaviour call you had to make. This is the part that gets
   corrected, so make it easy to correct.
5. **Verification** — what you ran, and what they should click to confirm.

No task-tracker jargon, no mode names, no file paths beyond the ones that mean something to them.

## Phase 7 — Watch until green

```bash
bash .claude/skills/ticket-to-pr/scripts/watch-pr.sh <pr> --interval 30 --timeout-min 45
```

Run it through `ctx_shell` with `run_in_background: true` and `timeout_ms: 3000000`, then poll
with `background_action: "status"`. Exit codes: `0` green, `1` red (failing logs written to
`.tmp/ci/pr-<pr>-run-<id>.log`), `2` timed out, `3` no checks ever registered.

On red:

1. The log is large — `ctx_search` it for the failing assertion or `tail` it. Do not `ctx_read`
   200KB of Actions output.
2. Decide whose failure it is. `gh run list --branch staging --workflow ci.yml --limit 5` tells
   you whether the same check is already failing on `staging`; if it is, say so in the PR and do
   not chase it.
3. Yours → `id-state.sh set EXECUTE`, fix the cause, re-gate locally, commit, push, watch again.
4. **Three red rounds is the limit.** Then stop, post what you know to the PR, and hand back.

Never get to green by weakening the check — no skipped test, no loosened assertion, no
`continue-on-error`, no gate downgrade. A green wall that stopped testing anything is worse than
a red one.

When it goes green, report: PR link, ticket link, what changed, what CI ran, and any assumption
still awaiting the reporter's confirmation.

---

## Stop and ask the human

- Working tree carries unrelated changes at Phase 5 — never fold someone else's work into your commit.
- The fix requires a data migration, deletes data, touches secrets/auth boundaries, or breaks a public API.
- The ticket, after ingest *and* research, has no derivable expected behaviour — not merely an
  unfilled template, but genuinely contradictory requirements across comments.
- Three failed CI rounds, or a failure that reproduces only in CI after two attempts.
- The lane turns out to be `heavy` and the plan wants more than one PR.

Everything short of those: decide, state the assumption, keep going.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `ctx_shell` refuses your download | write-doctrine guard hits `curl -o` and redirects | run `scripts/ingest-ticket.sh`; never inline the curl |
| Screenshot "unreadable" | you tried `ctx_read` on a `.png` | native `Read` — the routing hook allows image paths through on purpose |
| Write denied `[ID:<MODE>] blocks this write` | editing outside EXECUTE/SHIP | advance the mode; never shell around the ban |
| Turn will not end | Stop hook: lint or typecheck fails on changed TS | fix it; `CLAUDE_SKIP_STOP_GATE` is not the answer |
| PR opened against `main` | assumed GitHub's usual default | `--base staging`, always |
| `gh pr checks` exits 8 | checks still pending, not a failure | keep watching; that is what the script does |
| Attachment row says `DOWNLOAD-FAILED` | link expired or the asset needs a session cookie | ask the reporter to re-attach; do not guess the content |

## See also

- `.claude/id-workflow/PROTOCOL.md` — the rails this skill drives
- `.claude/skills/id-workflow/SKILL.md`, `.claude/skills/maestro/SKILL.md`
- `.claude/skills/plan-hierarchically/SKILL.md` — Phase 2 on the `heavy` lane
- `.claude/skills/pre-push-ci/SKILL.md` — the gate Phase 5 runs
- `.claude/README.md` — every hook quoted above, with its escape hatch
