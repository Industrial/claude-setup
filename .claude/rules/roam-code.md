# roam-code — Code Understanding Layer

CRITICAL: ALWAYS use roam-code to understand code. This is NOT optional.

roam-code pre-indexes symbols, call graphs, dependencies, architecture and git
history into a local SQLite database (`.roam/index.db`). One call answers what
five greps would, and it answers structurally — *who calls this*, *what breaks
if I change it*, *which tests cover it* — rather than textually.

## Tool mapping

| MUST USE | NEVER USE | Why |
|----------|-----------|-----|
| `roam_context(...)` **first** | a sequence of greps and reads | One call replaces 5–10; it is the orient step |
| `roam_search_symbol(name)` | `grep "fn name"` | Exact symbol, not every line mentioning it |
| `roam_uses(symbol)` | `grep -r name` | Call sites, not textual matches in comments |
| `roam_deps` / `roam_trace` | reading imports by hand | The graph is already built |
| `roam_impact(path)` | guessing the blast radius | What a change reaches |
| `roam_affected_tests(path)` | running the whole suite to find out | Which tests cover the change |
| `roam_understand(topic)` | reading a subsystem file by file | A synthesised answer over the index |
| `roam_explore` | `find` + `ls` to learn the shape | Structure, not a path dump |
| `roam_dead_code`, `roam_complexity_report` | manual audit | Precomputed |

## No language server

**roam-code needs no language server.** Its index is its own: a few megabytes of
SQLite, built once, queried in milliseconds.

That is the reason this rule exists in this form. A language server answering
the same questions costs **gigabytes of resident memory, per session, per
workspace** — measured on this machine at 4.8 GB across three rust-analyzer
instances, none of them an editor's, two of them more than a day old. Those
instances were the second-largest memory consumer on a 61 GB box and
contributed to a stream of OOM kills.

So: `rust-analyzer-lsp` is **disabled** in `settings.json`, serena is **removed**
from `.mcp.json`, and roam-code is how code gets understood. If you find
yourself wanting a language server, you want `roam_search_symbol`.

## Keep the index honest

The index is a snapshot. A stale index answers confidently about code that has
changed, which is worse than no index.

- Run `roam_health` when an answer looks wrong, or when the repository has
  gained or lost crates since you started. Its `_meta.index_age_s` is the
  number that matters.
- `roam_preflight` before a change, `roam_review_change` / `roam_diff` after.
- If the index predates the work you are doing, **reindex before trusting it**:
  `roam index` rebuilt this workspace — 829 files, 2,564 symbols — in **2.7
  seconds**. There is no excuse for working against a stale index.
- `roam hooks install` wires post-merge, post-checkout and post-rewrite
  re-indexing. It is installed here, and it does **not** cover ordinary
  commits, so a long session of edits still drifts. Check the age.

Measured, for calibration: the index was found **20 hours stale**, missing
three crates added that same session. A forced tool answering from a stale
index is worse than no rule, because the answers still look authoritative.

## Where roam-code stops

Three things it does not do, with what to use instead:

- **Reading a file's text.** That is lean-ctx's `ctx_read` — see
  `rules/lean-ctx.md`. roam-code tells you *which* file and *why*; lean-ctx
  gets you the bytes cheaply.
- **Editing.** lean-ctx's `ctx_patch`, per the same rule. roam-code is
  read-only by design.
- **Third-party library APIs.** That is context7's `query-docs`. roam-code
  indexes *this* repository, not its dependencies.

REMINDER: Understanding code starts with `roam_context`. Never with a grep.
