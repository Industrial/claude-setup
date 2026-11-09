# lean-ctx — Context Engineering Layer
<!-- lean-ctx-rules-v10 -->

CRITICAL: ALWAYS use lean-ctx tools instead of native equivalents, for reads
**and for writes**. This is NOT optional.

## Tool Mapping

| MUST USE | NEVER USE | Why |
|----------|-----------|-----|
| `ctx_read(path, mode)` | `Read` / `cat` / `head` / `tail` | Cached, 10 read modes, re-reads ~13 tokens |
| `ctx_search(pattern, path)` | `Grep` / `rg` | Compact, token-efficient results |
| `ctx_shell(command)` | `Shell` / `bash` / terminal | Pattern compression for git/npm/cargo output |
| `ctx_tree(path, depth)` | `ls` / `find` | Compact directory maps |
| `ctx_glob(pattern)` | `Glob` / `find -name` | Compact path lists |
| **`ctx_patch(...)`** | **`Edit` / `Write` / `StrReplace` / `NotebookEdit`** | **One call, no mandatory re-read, cross-file batches** |

## Writes go through ctx_patch

**There is no native-edit exemption.** Earlier versions of this rule said reads
were lean-ctx's and edits stayed native. That is withdrawn: `ctx_patch` is the
write path for every file change.

Pick the op by what you know:

| You have | op | Fields |
|----------|-----|--------|
| An exact unique snippet | `replace_unique` | `path`, `old_text`, `new_text` |
| A whole new file | `create` | `path`, `new_text` |
| A named function or type | `replace_symbol` | `path`, `name`, `new_text` |
| Line numbers + hashes from `ctx_read(mode="anchored")` | `replace_lines`, `set_line`, `insert_after`, `delete` | `path`, `line`/`start_line`+`end_line`, `hash`/`start_hash`+`end_hash` |
| A repeated substring, every occurrence | `replace_all` | `path`, `find`, `replace` |
| Several edits across several files | `ops: [...]` | one object per edit, applied atomically |

Notes that save a round trip:

- `replace_unique` needs **no prior read**. It is the direct `Edit` replacement
  and should be the default. If `old_text` is not unique the call fails rather
  than guessing — widen it and retry.
- `create` is the `Write` replacement. It is also how a new file is added, so
  there is no reason to reach for `Write` at all.
- Anchored ops are the precise ones, and the only ones that need a read first:
  `ctx_read(mode="anchored")` hands back the `line` and `hash` they want.
  `CONFLICT` means the file moved under you — re-read, do not retry blind.
- `dry_run: true` shows the patch without applying it. Use it when the edit is
  large or the anchors are stale.
- Batch with `ops: [...]` rather than firing N single-file patches. One call
  either applies wholly or not at all, which is what you want for a rename.

## ctx_read modes

- `auto` — auto-select optimal mode (recommended default)
- `full` — cached read (files you edit)
- `anchored` — line numbers + hashes, for the anchored `ctx_patch` ops
- `map` — deps + exports (context-only files)
- `signatures` — API surface only
- `diff` — changed lines after edits
- `aggressive` — maximum compression (context only)
- `entropy` — highlight high-entropy fragments
- `task` — IB-filtered (task relevant)
- `reference` — quote-friendly minimal excerpts
- `lines:N-M` — specific range

## Mode selection

1. About to patch by anchor? → `anchored`
2. Editing the file wholesale? → `full` first, then `diff` for re-reads
3. Need API surface only? → `map` or `signatures`
4. Large file, context only? → `entropy` or `aggressive`
5. Specific lines? → `lines:N-M`
6. Unsure? → `auto`

Anti-pattern: NEVER use `full` for files you won't edit — use `map` or
`signatures`. And never read a file *solely* to satisfy an edit tool's
precondition; `replace_unique` has no such precondition.

## Division of labour

lean-ctx moves bytes. It does not understand code.

- **Understanding code** — which file, who calls it, what a change breaks — is
  roam-code's, and is forced by `rules/roam-code.md`. Orient with
  `roam_context` *before* reading anything.
- **Reading and editing** those files is lean-ctx's, per this rule.
- **Third-party library APIs** are context7's `query-docs`.

## Proactive (use without being asked)

- `ctx_compose` to orient within a file set
- `ctx_session` to carry state across a long task

Fallback only if a lean-ctx tool is genuinely absent from the tool list — that
is the MCP server being disconnected, not a reason to prefer native tools.

REMINDER: Reads are `ctx_read`. Searches are `ctx_search`. **Writes are
`ctx_patch`.** Never native `Edit` or `Write`.
<!-- /lean-ctx -->
