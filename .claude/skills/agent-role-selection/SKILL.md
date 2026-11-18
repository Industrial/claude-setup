---
name: agent-role-selection
description: >-
  Pick the right agent role for the task. Use when deciding who does what on a multi-step delivery (maps to ID modes).
---

# agent-role-selection

From the id-workflow plugin agents (`harness/plugins/id-workflow/agents/*.md`):

| Role | Agent | Typical ID mode |
|------|------|-----------------|
| Researcher | `id-workflow:id-researcher` | ORIENT / RESEARCH |
| Architect | `id-workflow:id-architect` | PLAN |
| Implementer | `id-workflow:id-implementer` | EXECUTE |
| Reviewer | `id-workflow:id-reviewer` (+ `id-review-lens`) | REVIEW / SHIP |

State which agent you dispatch. Prefer the `id-workflow` skill so mode + agent stay aligned.
