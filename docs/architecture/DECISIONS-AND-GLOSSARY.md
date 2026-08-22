# Architecture decisions and domain glossary

## Purpose

This document freezes the consequential decisions required before repository initialization. It is intentionally implementation-neutral: it defines contracts, boundaries, and failure semantics, but does not prescribe application source code.

## Decision summary

| ID | Decision | Consequence | Revisit trigger |
|---|---|---|---|
| ADR-001 | Canonical project data is filesystem-first: Markdown with YAML frontmatter, YAML workflow manifests, and JSON/JSONL operational artifacts. | Users can inspect, back up, diff, and edit projects without the app. Parser and migration quality become critical. | A measured workload proves the format cannot support a required capability without destructive duplication. |
| ADR-002 | SQLite is a derived local index/cache, never canonical content. | Search and navigation are fast while deletion/rebuild remains safe. | A platform cannot provide an adequate embedded index, or project size exceeds local constraints. |
| ADR-003 | IDs are stable ULIDs/UUIDs; filenames are editorial slugs. References use IDs and may expose human-readable links. | Renames do not break dependency identity. A resolver and ambiguity diagnostics are required. | External ecosystems require a different stable identifier contract. |
| ADR-004 | Flutter is the primary cross-platform client for Windows and Android. | Domain, parser, engine, and most UI concepts can be shared. Native filesystem, secure storage, sharing, and notifications are isolated behind platform interfaces. | A proof-of-concept fails accessibility, editor quality, or platform integration acceptance criteria. |
| ADR-005 | The domain request model is provider-neutral; provider-specific adapters project it into a provider request and return a normalized response. | Provider differences are visible through capability negotiation instead of contaminating documents and workflows. | A provider standardizes a superset that materially changes the canonical message model. |
| ADR-006 | Promptflow is an explicit graph; repetition is represented only by a bounded loop construct. | Workflows remain statically inspectable and cannot contain accidental non-terminating cycles. | A later engine needs a formal state-machine model, which would be introduced as a versioned workflow schema rather than an implicit rewrite. |
| ADR-007 | Execution is deterministic at the orchestration layer and nondeterministic only at provider calls. | Budgets, retries, branches, approvals, and traces are testable independently of model quality. | A new execution mode requires distributed scheduling or long-running jobs. |
| ADR-008 | Versioning is hybrid: Git integration when available plus native snapshots and releases everywhere. | Windows users can use familiar Git workflows; Android remains useful without Git. | A supported collaboration backend supplies durable revision semantics. |
| ADR-009 | Google Drive is an optional synchronization and backup provider, not the database and not real-time collaboration. | Sync requires a common-base manifest, hashes, tombstones, conflict artifacts, and recovery UX. | A future hosted collaboration service provides transactional document-level merges. |
| ADR-010 | Credentials are device-local secure references and never project files. | Projects remain portable without leaking keys; account switching is explicit. | Enterprise policy requires managed key escrow or a team credential service. |
| ADR-011 | Consumer AI interfaces are supported by documented export/copy workflows only in the MVP; API adapters are the automation boundary. | No scraping, session injection, or undocumented browser automation is part of the core. | A provider publishes a supported integration contract that passes security and maintenance review. |
| ADR-012 | Schema migrations are explicit, idempotent, and versioned per file. | Older projects can be opened and upgraded with a backup and a report. | A stable industry schema is adopted without loss of project semantics. |
| ADR-013 | Logs are append-oriented, structured, redacted, and configurable by sensitivity level. | Runs remain debuggable while secret and sensitive-content exposure is limited. | Compliance requirements mandate an external audit store. |

## Non-negotiable invariants

1. A provider adapter cannot mutate canonical documents, workflow definitions, project metadata, or their hashes.
2. The local index can be deleted and fully rebuilt from canonical project files.
3. A sync operation cannot silently overwrite a file that changed on both sides since the recorded common base.
4. Every executable loop has a maximum iteration count, a timeout or budget policy, and an exhaustion path.
5. Every run records the workflow revision and dependency snapshot used to produce it.
6. Secrets are resolved at execution time from a credential store and are absent from project exports, ordinary logs, and snapshots by default.
7. An unsupported provider capability is surfaced before execution as `unsupported` or `degraded`; it is never silently emulated.
8. File names may be changed without changing canonical object identity.
9. Local browsing, editing, validation, search, snapshotting, and export do not require a network connection.
10. The filesystem format remains intelligible without knowing the internal database schema.

## Domain glossary

| Term | Definition | Not to be confused with |
|---|---|---|
| Project | A self-contained collection of AI-work artifacts, workflows, tests, outputs, and documentation. | A single prompt or a cloud account. |
| Document | A Markdown artifact with typed frontmatter and human-readable body. | A provider-specific message payload. |
| Prompt | A document whose body or message blocks are intended to guide model behavior. | An executable workflow. |
| Context | Reusable information injected into a request, with provenance and optional freshness metadata. | A secret or an implicit global memory. |
| Instruction | A reusable behavioral constraint or role definition; a system instruction is a placement/role, not a separate storage class. | A model capability. |
| Template | A parameterized document or message with declared variables. | A one-off rendered prompt. |
| Promptflow | A versioned, typed workflow graph that composes prompt, transform, control, evaluation, and human steps. | Prompt chaining by string concatenation only. |
| Loop | A bounded control construct that repeats a body/subflow until a declared stop condition, budget, or exhaustion policy. | An accidental graph cycle or autonomous agent. |
| Agent | A future or optional workflow profile with model, tools, memory, and policies; it is not privileged in the MVP. | A synonym for every workflow. |
| Run | One execution attempt of a workflow revision with inputs, outputs, events, and provenance. | A version or a saved prompt. |
| Evaluation | A structured judgment of a run or artifact using assertions, a rubric, a human review, or a model evaluator. | A provider response. |
| Snapshot | An immutable local capture of project state or dependency closure. | A mutable working copy. |
| Release | A named, tested project revision considered stable for reuse. | Every saved edit. |
| Adapter | A provider-facing translation and capability implementation. | A duplicate canonical prompt. |
| Capability | A declared feature such as structured output, tools, streaming, vision, or caching. | A guarantee that all providers behave identically. |
| Common base | The last local and remote state known to be identical for a sync item. | The latest local state. |
| Tombstone | A durable record that an object/file was deleted and must be reconciled. | A missing file with no history. |
| Workspace | A local application environment containing projects, index state, device identity, and credential references. | A shared cloud tenant. |

## Boundary rules

The **domain layer** owns meaning and validation. The **filesystem layer** owns serialization and atomic writes. The **index layer** owns derived query structures. The **engine** owns graph execution and trace events. The **adapter layer** owns transport-specific projection. The **sync layer** owns remote reconciliation. The **UI** owns presentation and user interaction. No layer may reach through another layer to bypass its interface.

A project file may contain content and non-secret configuration, but it may not contain API keys, OAuth refresh tokens, access tokens, device secrets, or unbounded raw provider response data. A run may reference a raw response artifact by a local URI or hash; the default trace stores only the normalized response and redacted diagnostics.

## Definition of done for the planning phase

This decision set is complete when the data schemas, sample project, adapter matrix, sync protocol, UX blueprint, implementation tickets, and acceptance tests can be written without reopening the foundational choices above. Remaining uncertainty must be parameter-level, not architectural.

## References

[1]: https://docs.flutter.dev/platform-integration/desktop "Flutter desktop support"
[2]: https://docs.flutter.dev/cookbook/persistence/reading-writing-files "Flutter file persistence"
[3]: https://developers.google.com/workspace/drive/api/reference/rest/v3 "Google Drive API reference"
[4]: https://developers.google.com/workspace/drive/api/guides/change-overview "Google Drive changes and revisions overview"
[5]: https://modelcontextprotocol.io/specification/2026-07-28 "Model Context Protocol specification"
[6]: https://sqlite.org/wal.html "SQLite write-ahead logging"
