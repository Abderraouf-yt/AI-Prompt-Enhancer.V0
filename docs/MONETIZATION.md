# Monetization foundation

The MVP now contains a local-only entitlement and event foundation. It is intentionally **not** a billing system and does not claim to validate payment or account status. Its purpose is to keep the product boundary explicit while the activation funnel is measured.

The free experience remains useful without an account. It includes local project storage, paste/file capture, local detection, reusable Markdown/YAML export, local preview, and secure user-key provider execution. URL capture is limited to three local captures in the default entitlement object. When the limit is reached, the user sees a concrete Pro explanation rather than a generic paywall.

The upgrade message is attached to a value boundary: unlimited URL/GitHub capture, version restore, cross-device sync, and multi-provider comparison. The UI does not ask for payment credentials and does not pretend that checkout is connected. A future account service can replace the local `entitlement.json` with a signed entitlement response without changing the UI feature checks.

Product events are stored in `.promptworkspace/events.jsonl` with timestamps and allowlisted metadata only. Prompt contents, provider keys, and long free-form strings are not logged. Current event names include `capture_review_opened`, `url_capture_started`, `asset_saved`, `run_completed`, and `upgrade_viewed`. These events are sufficient to measure activation and upgrade intent before adding analytics infrastructure.

The next revenue implementation should add an authenticated entitlement API, server-side feature flags, a checkout provider, usage metering for any hosted inference, and a deletion/export policy for event data. It must not remove the free local export path or require an account before the first successful save-and-reuse loop.
