---
name: skill-library
description: >-
  Finds skills held off the session roster. Every skill on this machine lives in
  ~/.claude/skills/ as real content; the roster only carries descriptions for a
  subset, so the rest appear by name alone or not at all. Invoke to discover what
  exists before concluding a capability is missing, or when a task needs expertise
  outside the default roster.
---

# Skill library

There is **one** skill tree: `~/.claude/skills/`. Every skill is a real directory
there with a `SKILL.md`. Nothing needs installing, fetching, or moving.

What varies is only whether a skill spends a **roster line** at session start:

- **On the roster** — listed in `~/.claude/skills.manifest`, description loaded at
  session start, auto-invocable without being named.
- **Off the roster** — set to `user-invocable-only` in `~/.claude/settings.json`
  under `skillOverrides`. Still installed, still `/name`-invocable, still readable
  by path. It just does not spend roster budget until you go looking.

## Why the roster is rationed

Claude Code concatenates every rostered skill's name and description at session
start and **truncates that string when it overflows** — mid-word, with every entry
after the cut arriving as a bare slug. A skill whose description never reaches the
model cannot be auto-invoked, so it costs a line and buys nothing.

The budget is **characters, not entries**: measured at 81 entries / 26,629 chars the
cut landed around position 73, while a 75-char description at position 78 still fit.
The ceiling sits near 21,000 chars. Keep the roster under ~18,000 for margin.

## Finding a skill

This file deliberately carries **no embedded list**. A generated index goes stale the
moment a skill is added or renamed, and there is no longer a sync script to rebuild
it. Read the tree instead — it is always correct:

```bash
# every skill on the machine
ls ~/.claude/skills/

# search names
ls ~/.claude/skills/ | grep -i <topic>

# what a candidate actually does — frontmatter is the summary
head -12 ~/.claude/skills/<name>/SKILL.md

# search descriptions across all of them
grep -l -i '<topic>' ~/.claude/skills/*/SKILL.md
```

Then read the full `SKILL.md` for the one you want.

## Putting a skill on the roster

Add its **directory name** to `~/.claude/skills.manifest` and delete the matching
`skillOverrides` entry in `~/.claude/settings.json`. Removing one is the reverse.
Nothing moves on disk either way.

The identity Claude Code uses is the **directory name**, not the frontmatter `name:`
— 28 skills differ between the two (`dev-caches-cleanup` declares
`linux-dev-caches-cleanup`, the `id-effect-*` family declares `id_effect-*`). Key
both files on the directory name or the override silently fails to match.
