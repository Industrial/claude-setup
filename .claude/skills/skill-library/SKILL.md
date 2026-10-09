---
name: skill-library
description: >-
  Finds skills that carry no description in the session roster. Every skill lives
  in this repo's .claude/skills/ as real content; the roster carries descriptions
  for a rostered subset and bare names for the rest. Invoke to work out what a
  name-only skill actually does before using it, or to check whether a capability
  exists at all before concluding it is missing.
---

# Skill library

There is **one** skill tree, and it is **in this repository**, not your home
directory:

```
${CLAUDE_PROJECT_DIR}/.claude/skills/<name>/SKILL.md
```

`.claude` is a symlink to `.claude-setup/.claude`, a git submodule shared across
repos. `~/.claude/skills/` holds only `lean-ctx` and the claude.ai `synced/`
folder — it is **not** the library, and earlier versions of this file pointed
there by mistake.

Every skill is a real directory with a `SKILL.md`. Nothing needs installing,
fetching, or moving. What varies is only how much of it reaches the model at
session start:

- **Rostered** — listed in `.claude/skills.manifest`. Name *and* description
  reach the model, so Claude can auto-match it without being told it exists.
- **Name-only** — set to `"name-only"` in `.claude/settings.json` under
  `skillOverrides`. The name reaches the model, the description does not. Still
  installed, still `/name`-invocable by you, and **still invocable by Claude** —
  it just cannot be matched from a description, so something has to recognise the
  name. That is what this skill is for.

> Do **not** use `"user-invocable-only"` for the long tail. That state hides the
> skill from the model entirely — Claude cannot invoke it, so a router can find a
> skill and still be unable to run it. `"name-only"` costs about 20 characters
> against a description's ~330 and keeps invocation working.

## Why the roster is rationed

Claude Code concatenates every rostered skill's name and description at session
start and **truncates that string when it overflows** — mid-word, with every entry
after the cut arriving as a bare slug. A skill whose description never reaches the
model cannot be auto-invoked, so it costs a line and buys nothing.

The budget is **characters, not entries**, and it is pinned in
`.claude/settings.json` rather than inherited:

```json
"env": { "SLASH_COMMAND_TOOL_CHAR_BUDGET": "30000" }
```

Pinned because the default scales with the model's context window, which silently
moves the ceiling when you switch models. The earlier measured ceiling of ~21,000
chars was taken on a different model and no longer applies.

Current spend: ~16,600 chars of rostered descriptions plus 3,590 of bare names.
Re-measure with `/context` (the Skills row reports the post-budget size) and
`/skill-doctor` (per-skill cost and invocation counts).

## Finding a skill

This file deliberately carries **no embedded list**. A generated index goes stale the
moment a skill is added or renamed, and there is no longer a sync script to rebuild
it. Read the tree instead — it is always correct.

Every skill's name is already in your roster, so usually you only need to learn
what a name you can already see actually means:

```bash
# what a candidate does — frontmatter is the summary
head -14 ${CLAUDE_PROJECT_DIR}/.claude/skills/<name>/SKILL.md

# search names by topic
ls ${CLAUDE_PROJECT_DIR}/.claude/skills/ | grep -i <topic>

# search descriptions across every skill
grep -il '<topic>' ${CLAUDE_PROJECT_DIR}/.claude/skills/*/SKILL.md

# which skills are rostered rather than name-only
grep -vE '^#|^$' ${CLAUDE_PROJECT_DIR}/.claude/skills.manifest
```

In this repo native `Read`/`Grep`/`Bash` are routed to lean-ctx by the
`id-workflow` hooks — use `ctx_read`, `ctx_search`, `ctx_tree` and `ctx_shell`
for the equivalents above. If lean-ctx is unreachable the native tools are the
fallback; do not conclude the library is empty because one tool path is blocked.

Then read the full `SKILL.md` for the one you want, and invoke it by name.

## Moving a skill between tiers

| Direction | Action |
|---|---|
| name-only → rostered | add the directory name to `.claude/skills.manifest`, **and** delete its `skillOverrides` entry in `.claude/settings.json` |
| rostered → name-only | remove it from the manifest, **and** add `"<dir>": "name-only"` to `skillOverrides` |

Both files must agree. A skill in **neither** is treated as fully rostered by
default — it spends a whole description's budget without appearing in the
manifest, which is how `scientific-method` was being paid for silently until
2026-10-09. Nothing moves on disk either way.

Verify all three sources agree — directories, manifest, overrides — before
trusting any count:

```bash
cd ${CLAUDE_PROJECT_DIR}/.claude
comm -23 <(ls -d skills/*/ | sed 's|skills/||;s|/$||' | sort) \
         <(cat <(grep -vE '^#|^$' skills.manifest) \
               <(jq -r '.skillOverrides|keys[]' settings.json) | sort -u)
```

Empty output means every skill is accounted for. Any name printed is being
rostered by accident.

The identity Claude Code uses is the **directory name**, not the frontmatter `name:`
— 28 skills differ between the two (`dev-caches-cleanup` declares
`linux-dev-caches-cleanup`, the `id-effect-*` family declares `id_effect-*`). Key
both files on the directory name or the override silently fails to match.
