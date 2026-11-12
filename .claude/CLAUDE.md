# Agent tooling — forced routing

Two MCP servers are mandatory here, and they split the work cleanly:
**roam-code understands code, lean-ctx moves bytes.** Full rules in
`rules/roam-code.md` and `rules/lean-ctx.md`; the short form follows.

## Understanding code → roam-code (NOT optional)

| ALWAYS USE | NEVER USE | Why |
|------------|-----------|-----|
| `roam_context(...)` **first** | a chain of greps and reads | One call replaces 5–10; this is the orient step |
| `roam_search_symbol(name)` | `grep "fn name"` | The symbol, not every line naming it |
| `roam_uses(sym)` / `roam_deps` / `roam_trace` | reading imports by hand | The call graph is already built |
| `roam_impact(path)` / `roam_affected_tests(path)` | guessing the blast radius | What a change reaches, and what covers it |
| `roam_understand(topic)` / `roam_explore` | reading a subsystem file by file | Synthesised over the index |

**No language server.** roam-code's index is its own SQLite file — megabytes,
not gigabytes. `rust-analyzer-lsp` is disabled and serena is removed, because
three stray rust-analyzer instances cost 4.8 GB and helped OOM a 61 GB box. If
you want a language server, you want `roam_search_symbol`.

Start every code question with `roam_context`. Never with a grep.

<!-- lean-ctx-rules-v10 -->
## Reading and writing files → lean-ctx (NOT optional)

| ALWAYS USE | NEVER USE | Why |
|------------|-----------|-----|
| `ctx_read(path, mode)` | `Read` / `cat` / `head` / `tail` | Cached, 10 modes, re-reads ~13 tokens |
| `ctx_search(pattern, path)` | `Grep` / `rg` | Compact, token-efficient results |
| `ctx_shell(command)` | `Shell` / `bash` / terminal | Pattern compression for git/cargo output |
| `ctx_tree(path, depth)` / `ctx_glob(pattern)` | `ls` / `find` / `Glob` | Compact directory maps |
| **`ctx_patch(...)`** | **`Edit` / `Write` / `StrReplace`** | **One call, no mandatory re-read, atomic cross-file batches** |

**Writes go through `ctx_patch`. There is no general native-edit exemption** — earlier
versions of this file said edits stayed native, and that is withdrawn.

**One exception, and only one: bypass-permissions sessions.** When the harness
injects its bypass-mode instruction — "do your work through the Bash tool
wherever it can accomplish the job … make file changes with sed, heredocs, or
short scripts" — that arrives as a mid-conversation system turn and outranks
this file. In that mode Bash writes are correct and expected; `ctx_patch` stays
preferred wherever it is available and no less direct. Everywhere else the rule
above holds with no exemption. Do not spend turns trying to satisfy both — see
`rules/lean-ctx.md` for the full carve-out.

- `op="replace_unique"` with `path`, `old_text`, `new_text` is the `Edit`
  replacement, and needs **no prior read**. Default to it.
- `op="create"` with `path`, `new_text` is the `Write` replacement.
- `op="replace_symbol"` edits a named function or type.
- `ops: [...]` applies many edits across many files atomically — prefer it to
  N separate calls.
- Anchored ops (`replace_lines`, `set_line`, `insert_after`, `delete`) take
  `line`/`hash` from `ctx_read(mode="anchored")`. `CONFLICT` means re-read.

NEVER loop on a failed patch — a non-unique `old_text` wants widening, not
retrying, and it never wants a fallback to `Edit`.
<!-- /lean-ctx -->

## Everything else

Third-party library APIs are context7's `query-docs` — not a web search, and
not your recollection of the API.
