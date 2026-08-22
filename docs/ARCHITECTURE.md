# Implementation architecture

## Current layers

```text
Flutter UI
  ├── Inbox capture and review
  ├── Library search and edit
  ├── Runs and outputs
  └── Power tools
  ↓
PromptRepository + UI application services
  ↓
Canonical project files
  ├── Markdown documents with YAML frontmatter
  ├── YAML project/workflow manifests
  └── JSON run history and import captures
  ↓
Derived JSON index and local search
  ↓
ProviderGateway
  ├── Local preview adapter
  ├── OpenAI Responses API projection
  ├── Anthropic Messages API projection
  └── Gemini generateContent projection
  ↓
Native secure storage for credentials
```

The repository is deliberately local-first. Project files are the source of truth. The index can be deleted and rebuilt by opening the project. The original imported material is captured before adaptation so a user can recover the exact source. Local `entitlement.json` and `events.jsonl` are product-operation artifacts, not authoritative billing records and not canonical content.

## Reuse Before Recreate

`PromptRepository.analyzeImport` performs local, deterministic analysis. It does not require metadata and does not call an LLM. It detects Markdown headings, variable conventions such as `{{name}}`, `[NAME]`, `<NAME>`, and `$name`, likely objectives, constraints, references/context clues, provider assumptions, and hard-coded candidates.

`PromptRepository.saveImport` writes a new Markdown asset with a versioned frontmatter block. It records the origin label, import timestamp, content hash, adaptation mode, current project reference, changed sections, and any composition source references. The raw capture is stored under `.promptworkspace/imports/`. `{{variable}}` is used as the readable template syntax.

Composition is intentionally lightweight. The user may select one existing indexed asset in the adaptation view; the MVP appends it under a labeled reusable-component section and records the source ID. A future composition editor can replace this deterministic operation with section-level keep/merge/replace/variableize actions without changing the provenance fields.

## Provider boundary

The UI separates local preview from live provider execution. The provider gateway resolves API keys from `flutter_secure_storage`, never from the project folder. OpenAI uses a Responses API request, Anthropic uses a Messages API request, and Gemini uses a `generateContent` request. Provider-specific response parsing is isolated in the gateway. Unsupported or failed network calls are recorded as failed runs with a user-readable message.

## Revenue boundary

The MVP includes a local feature gate for a limited free URL-capture allowance, a Pro upgrade explanation, and privacy-safe funnel events. There is no checkout, account service, or server-authoritative entitlement yet. A future backend can replace the local entitlement file without changing the canonical asset model.

## Known implementation boundary

The approved architecture package described SQLite/FTS5, full graph Promptflow execution, evaluations, Git snapshots, Google Drive synchronization, and Windows/Android packaging. The current implementation slice intentionally delivers the user-visible import/reuse path first and uses a JSON index to avoid a native database dependency in the first runnable build. The remaining features remain documented as explicit next tickets rather than hidden mock functionality.
