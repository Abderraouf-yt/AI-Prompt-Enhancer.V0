# Canonical project-file specification v1

## Scope

A project is a portable folder whose content is meaningful without the application. The application may add a derived `.promptworkspace/` directory, but deletion of that directory must not delete or invalidate canonical data. The implemented MVP writes `.promptworkspace/index.json`; the planned SQLite/FTS5 index remains an upgrade path once measured repository size justifies the native database dependency.

## File classes

| Class | Extension | Canonical | Human editable | Required metadata |
|---|---|---:|---:|---|
| Project manifest | `.yaml` | Yes | Yes | `schema`, `id`, `slug`, `title`, timestamps, status |
| Reusable document | `.md` | Yes | Yes | YAML frontmatter conforming to `document/v1` |
| Workflow | `.yaml` | Yes | Yes | `workflow/v1` schema |
| Test case | `.yaml`, `.json`, or `.md` | Yes | Yes | `test/v1` or document schema |
| Evaluation rubric | `.md` or `.yaml` | Yes | Yes | `evaluation` kind or `evaluation/v1` |
| Reference metadata | `.md` or `.yaml` | Yes | Yes | provenance and optional checksum |
| Asset | Original format | Yes | With external tool | Sidecar metadata optional |
| Run event log | `.jsonl` | Optional | Inspectable | `run/v1` events and redaction policy |
| Sync state | `.json` | No | Not normally | `sync-state/v1`; device/account-local |
| Derived index (MVP) | `.json` | No | No | Reconstructible from canonical files; SQLite/FTS5 remains the next scale upgrade |

## Identity and names

Every durable object has a stable ID with a type prefix, such as `prompt:generate-review` or `workflow:content-review-v1`. The current convention allows ULID/UUID-like opaque IDs in production, while fixtures may use readable IDs. A filename is a slug and is not identity. Renaming a file must update display metadata and links where possible, but must not create a new object.

References should use canonical IDs in YAML and frontmatter. Markdown bodies may use standard Markdown links or Obsidian wiki-links. The parser resolves both forms, records unresolved links as diagnostics, and never treats a display title as a unique identity if more than one object has that title.

## Frontmatter rules

The opening frontmatter block must be delimited by `---` on its own line. Dates use RFC 3339 UTC strings. Tags are lowercase, stable, and unique within a document. Unknown fields cause a warning in compatibility mode and an error in strict execution mode; the application must preserve unknown fields during round-trip serialization so an external editor or future schema does not lose information.

The Markdown body is opaque to the domain except for declared message blocks and variable references. `{{variable_name}}` is the canonical template marker in v1. A renderer must escape or reject undeclared variables according to project strictness settings. Secret variables may be used at runtime but are never included in normal rendered-output logs.

## Atomic writes and recovery

The writer must write to a sibling temporary file, flush and close it, then rename it into place. Before a schema migration, it must create a recoverable backup or snapshot. A partially written file is invalid and must not replace the last known valid version. The scanner should retain the last valid index record while showing a filesystem diagnostic until the file is corrected.

## Dependency closure

A run stores the root workflow ID and revision plus the IDs and content hashes of every referenced document, context, evaluation, subflow, and provider adapter descriptor. The closure is a provenance record, not a copied canonical prompt. A release is valid only when every referenced object resolves and every object passes its schema and semantic validation.

## Migration rules

Each file declares its schema version. A migration is a pure function from one version to the next, is idempotent, emits a report, and preserves the original file until the user accepts the upgrade or an automatic backup exists. The application must support opening older supported versions in read-only compatibility mode if a migration cannot be completed.

## Compatibility profile

The **Obsidian-compatible profile** uses ordinary Markdown, YAML frontmatter, simple scalar/list properties, and links that Obsidian can display. The product does not require Obsidian plugins, canvas files, proprietary block IDs, or Obsidian-specific databases. Obsidian is a compatible external editor and graph surface, not the application runtime.

## Validation levels

| Level | Purpose | Failure behavior |
|---|---|---|
| Syntax | Parse YAML/JSON/Markdown delimiters | File marked unreadable; last valid index retained |
| Schema | Validate required fields and types | File marked invalid; visible but not executable |
| Semantic | Resolve IDs, ports, variables, graph constraints, loop budgets | Workflow cannot run; diagnostics point to fields |
| Provider | Check selected adapter capabilities and credential availability | Run blocked or explicitly degraded before network call |
| Runtime | Enforce timeouts, budgets, retries, cancellation, approval | Run pauses, fails, or routes to review per policy |
