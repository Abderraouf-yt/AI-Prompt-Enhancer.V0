# Refactor audit baseline

The current repository is clean on `main` and the existing Flutter service and widget tests pass. The implementation already has a useful local-first foundation: canonical Markdown/YAML assets, import analysis, raw-capture preservation, provenance fields, secure provider storage, local preview execution, and responsive Flutter UI.

The primary refactor risk is not data corruption; it is user friction. The current UI exposes six navigation concepts, creates a project before the first useful capture, and asks the user to choose among many import outcomes before they have seen a recommendation. The code also treats some roadmap capabilities as visible product surfaces even though workflows, sync, and evaluations are not fully implemented.

The refactor will keep `PromptRepository` and the canonical file format as the storage boundary. It will simplify the UI first, then add capture metadata, safer URL handling, per-variable test inputs, revision metadata, deterministic related-asset suggestions, provider capability metadata, and a local entitlement/event layer. The refactor will not introduce a backend, vector database, agent runtime, or payment processor into the MVP source tree before the local activation funnel is observable.

The existing test baseline is three passing tests: structure and variable detection, provider-assumption/missing-information detection, and root-widget rendering. The refactor must preserve these tests and add coverage for capture persistence, variable rendering, revision metadata, related-asset ranking, URL safety, entitlement gating, and privacy-safe event payloads.
