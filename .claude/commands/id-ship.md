---
description: ID SHIP — land the work: ship the task, commit, push or PR, close the session
argument-hint: "[tsk-id]"
---

[ID:SHIP]

Read: `<id-pack>/modes/ship.md`, `checklists/ship-exit.md`.

## Sequence

1. `maestro_task_ship <tsk-id>` once the verdict is PASS.
2. Commit per the user's rules. Never delete branches — local or remote — that rail is absolute and
   `guard-bash.sh` blocks it.
3. Push only when the user asked or the session is closing.
4. Prefer the program over ad-hoc commands:
   ```
   devenv shell -- definitively run .definitively/programs/session-close.yml
   ```
   `/pre-push` is the lighter parity path.
5. Emit a handoff envelope if the work continues elsewhere.
6. If a submodule (e.g. `.claude-setup`) changed, update the parent submodule gitlink.

## Close out ID

When the work is done, disengage so the next session starts clean:

```
bash plugins/id-workflow/hooks/id-state.sh clear
```

Leave it engaged only if the pipeline genuinely continues in the next session — `session-id-context.sh`
will restore the mode there.

## Exit

- [ ] Maestro task shipped (or N/A for an untracked tiny)
- [ ] Commits created where required
- [ ] Push / PR done where required
- [ ] Parent submodule gitlink updated if a submodule changed
- [ ] ID state cleared or deliberately carried forward

$ARGUMENTS

`<id-pack>` is `.claude/id-workflow/` in a project that carries its own copy of the pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in every project.
