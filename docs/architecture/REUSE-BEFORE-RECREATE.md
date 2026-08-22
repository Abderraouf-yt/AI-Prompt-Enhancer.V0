# Reuse Before Recreate — integrated product requirement

## Status

This is an extension of the approved Promptflow OS architecture, not a separate subsystem. It changes the first-run UX, import contracts, provenance metadata, lightweight discovery, and the vertical implementation order. The canonical filesystem, derived SQLite index, Promptflow engine, provider adapters, sync boundary, local credentials, and no-backend MVP remain valid.

## Core principle

> **Reuse Before Recreate:** when a user finds useful material outside or inside the workspace, the fastest path is to capture it, understand it, adapt it, test it, save it, and reuse it—not to recreate it manually.

The canonical user path becomes:

```text
FIND → IMPORT/PASTE → DETECT → UNDERSTAND → ADAPT → TEST → SAVE → REUSE → EXECUTE
```

This path is embedded in project overview, quick open, command palette, empty states, workflow creation, and prompt creation. It is not a standalone recommendation platform.

## Minimal new domain capability

The system adds a transient **Import Capture** and **Adaptation Proposal** concept. These are workspace operations, not durable canonical entities unless the user saves them. An Import Capture contains raw content, origin metadata, detected format, content hash, and an analysis result. An Adaptation Proposal contains selected destination kind, project context references, variable candidates, proposed changes, provenance links, and a user decision. Once accepted, the result becomes an ordinary canonical Document, Workflow Node, Reference, or Asset with `provenance.source_type`, `provenance.source_refs`, `provenance.adaptation`, and optionally `derived_from`.

No vector database, autonomous agent, or mandatory cloud analysis is introduced. Detection uses local heuristics first: Markdown frontmatter, headings, role markers, variable patterns, JSON/YAML shape, code fences, common instruction labels, and explicit project references. Optional provider-assisted analysis may be invoked only after user action and only through the existing adapter contract; the MVP remains useful without it.

## Detection output

The concise result answers:

| Question | MVP output |
|---|---|
| What is this? | Suggested kind, title, objective, format, and confidence |
| What does it need? | Detected inputs, variables, referenced files, provider assumptions, missing information |
| What can be reused? | Sections, variables, context blocks, constraints, examples, and matching workspace assets |
| What should become a variable? | Candidate placeholders with inferred type, required/optional status, and confidence |
| What should adapt? | Project-specific terms, hard-coded values, role/instruction placement, provider formatting |
| What can be preserved? | Original raw content, untouched sections, origin URI/label, content hash, and diff |

The analysis is a compact structured card, not a long generated essay. The user can open technical detail on demand.

## Quick actions

The import surface must offer one-click or one-confirmation actions for `Use as-is`, `Adapt to project`, `Convert to template`, `Extract reusable components`, `Compare with existing`, `Combine`, `Add to workflow`, and `Save as`. `Save as` supports Prompt, Template, Context, Instruction, Workflow Node, Project Asset, and Reference. The original capture is preserved whenever the user chooses a derived result.

## Composition model

Composition is explicit and inspectable. The user selects two or more source assets, project context, variables, and optional requirements. The system creates a proposal with a source list, section-level operations (`keep`, `merge`, `replace`, `remove`, `variableize`), and a diff. The resulting asset stores `source_refs` and `derived_from`; it does not overwrite any source. Automatic composition is limited to deterministic concatenation/section ordering in the MVP, with optional provider-assisted drafting clearly labeled as generated adaptation.

## Reuse discovery

Reuse suggestions use the existing SQLite index: exact/normalized text matches, title/tags, shared references, declared input/output compatibility, document kind, and lightweight token overlap. Results are ranked as **similar**, **compatible**, or **same content** and always explain the matching signals. This is deliberately not semantic retrieval and does not require embeddings.

Existing similar assets appear when the user creates a prompt, starts a workflow, imports content, or opens an empty project. The user can `Reuse`, `Adapt`, `Compare`, `Clone`, or `Use as subflow`. There is no opaque automatic replacement of user intent.

## Integration with provider delivery

An adapted asset may be executed through an API adapter or prepared for a consumer interface. The delivery panel distinguishes `Execute through API` from `Prepare for consumer interface`, and offers copy system/user sections, copy complete context package, Markdown/text/JSON/ZIP export, and Android share/export when available. Provider projection warnings remain visible and canonical content stays unchanged.

## Integration with evaluation and workflow

An imported/adapted asset can be tested before saving through a temporary run or can be saved as a draft and then added to a workflow. A workflow node records the source document ID and revision. A proposal is never executable until its destination asset passes schema and semantic validation.

## Updated acceptance intent

A first-time user must be able to paste an unstructured prompt, understand what the app detected, accept an adaptation to the current project, approve variables, save it as a template without losing the original, find it through search, add it to a workflow, run it, inspect the result, and export a provider-ready projection with materially fewer manual steps than recreating the prompt.
