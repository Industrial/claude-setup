---
name: skills
description: >
  Scan available skills across BOTH roster tiers and select every skill that
  materially improves this task. Most skills reach you as a bare name with no
  description — do not mistake that for absence; read its frontmatter before
  ruling it out. Before acting: list reviewed vs using. Load and follow each
  selected skill. Prefer fewer, higher-leverage skills over a long weak list.
  Prefer `/id` (ORIENT runs this step). Include `id-workflow` when mode-gated
  delivery applies.
tags: [skill-selection, workflow, optimization]
---

# Skill Selection

## Purpose
Scan available skills. Select every skill that materially improves this task; skip the rest.
Before acting: list **reviewed** vs **using** (paths only). Load and follow each selected skill.
Prefer fewer, higher-leverage skills over a long weak list.

## Read both tiers — your roster is deliberately incomplete

This repo rations the skill listing. ~231 skills are installed; only ~50 carry a
description. The rest arrive as **a bare name and nothing else**.

| Tier | What you receive | How you find it |
|---|---|---|
| **Rostered** (~50) | name + full description | matches your task automatically |
| **Name-only** (181) | name alone | you must recognise the name, then read its frontmatter |

A name-only skill is fully installed and **you can invoke it**. The only thing
missing is the description that would have let you match it. So:

- **Never conclude a capability is missing** because nothing in your roster
  described it. Scan the bare names too — they are in your roster, just silent.
- When a name looks plausibly relevant but you cannot tell from the name alone,
  read its frontmatter before deciding:
  `ctx_read("${CLAUDE_PROJECT_DIR}/.claude/skills/<name>/SKILL.md", mode="lines:1-14")`
- To search by topic rather than guess at names, invoke **`skill-library`**. That
  is its entire job, and it holds the current recipes.
- `${CLAUDE_PROJECT_DIR}/.claude/skills.manifest` lists exactly which skills are
  rostered; everything else in `.claude/skills/` is name-only.

## Guidelines
1. **Review both tiers** - Scan rostered descriptions *and* the bare names. The long tail is where repo-specific expertise lives.
2. **Select only material improvements** - Choose skills that meaningfully enhance the task
3. **Skip irrelevant skills** - Don't load skills that don't add value to the current context
4. **List reviewed vs using** - Document which skills you considered and which you actually use
5. **Prefer fewer, higher-leverage skills** - Quality over quantity in skill selection
6. **Prefer `/id` for ORIENT** - When in ORIENT mode, the `/id` command runs this skill selection step
7. **Include `id-workflow` for mode-gated delivery** - When doing mode-gated work, include the ID workflow skill

## Usage in ID Workflow
During **ORIENT** mode of the ID workflow:
1. Run this skill selection process to determine which skills to load
2. List the skills you reviewed (examined for relevance)
3. List the skills you're actually using (selected for material improvement)
4. Load and follow each selected skill
5. Always include `id-workflow` when doing mode-gated delivery

## When nothing fits

Before reporting that no skill covers the task, do one pass through
`skill-library` searching descriptions by topic. The roster is budget-rationed,
not a statement about what exists — a silent name is still a skill. If a genuine
gap remains after that pass, `new-skill` is how you close it.

## Example Output
When asked to select skills for a task, you might respond:
```
Reviewed skills:
- id-workflow
- id-orient
- new-skill
- quality
- plan-hierarchically

Using skills:
- id-workflow
- id-orient
- quality

[Then proceed with the selected skills loaded and active]
```

This ensures you're using the most relevant skills for each task without cluttering your context with unnecessary information.