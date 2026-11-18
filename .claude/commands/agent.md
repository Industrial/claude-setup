Pick the right agent for the task from the id-workflow plugin agents (`harness/plugins/id-workflow/agents/*.md`):

| Role | Agent | Typical ID mode |
|------|------|-----------------|
| Researcher | `id-workflow:id-researcher` | ORIENT / RESEARCH |
| Architect | `id-workflow:id-architect` | PLAN |
| Implementer | `id-workflow:id-implementer` | EXECUTE |
| Reviewer | `id-workflow:id-reviewer` (+ `id-review-lens`) | REVIEW / SHIP |

State which agent you dispatch. Prefer `/id` so mode + agent stay aligned.
