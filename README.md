# Promptflow OS

Promptflow OS is a local-first AI work engineering workspace for Windows and Android. The current MVP is built with Flutter and focuses on the fastest useful path: **FIND → IMPORT/PASTE → DETECT → UNDERSTAND → ADAPT → TEST → SAVE → REUSE → EXECUTE**.

It is designed around the principle **Reuse Before Recreate**. A prompt copied from a website, GitHub, community, another AI tool, or a local file can be captured without frontmatter, analyzed locally, converted into a prompt/template/context/instruction/reference, adapted to the current project, and saved without destroying the original capture.

## Implemented in this repository

The application currently provides actual project creation and reopening under the platform application documents directory, canonical Markdown/YAML project folders, derived JSON indexing and full-text filtering, prompt editing, clipboard capture, Markdown/TXT/YAML/JSON file import, local structure detection, candidate variable extraction, adaptation preview, template conversion using `{{variable}}`, explicit project-context markers, provenance metadata, original preservation, lightweight composition with an existing asset, workflow draft generation, run history, deterministic local preview execution, optional OpenAI/Anthropic/Gemini HTTP adapter paths, native secure credential storage, clipboard export, and responsive desktop/mobile UX.

The canonical project structure is:

```text
<ProjectSlug>/
├── project.yaml
├── README.md
├── prompts/
├── templates/
├── context/
├── instructions/
├── workflows/
├── evaluations/
├── references/
├── assets/
├── runs/history.json
└── .promptworkspace/
    ├── imports/
    └── index.json
```

The canonical files remain ordinary Markdown and YAML. `.promptworkspace/index.json`, `runs/history.json`, and the import capture copies are derived or operational artifacts. Credentials are stored through `flutter_secure_storage` and are not written to project files, exports, or run outputs.

## Run locally

Install Flutter 3.47 or newer, then run:

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run -d linux
```

For Android, install the Android SDK and set `ANDROID_SDK_ROOT`, then run:

```bash
flutter build apk --release
flutter install
```

For Windows, use a Windows development machine with Visual Studio Desktop C++ tooling:

```powershell
flutter build windows --release
```

A Linux release smoke build is available at `build/linux/x64/release/bundle/` when the Linux desktop toolchain is installed. The current sandbox can compile Linux, but it cannot produce a native Windows executable because Flutter Windows builds require the Windows/Visual Studio toolchain. Android packaging also depends on Gradle artifact availability and a configured Android SDK.

## First-use flow

Open the app and create a project if the default workspace is empty. Press **Paste prompt** or **Import file**. The capture view detects the likely kind, objective, sections, variables, constraints, dependencies, provider assumptions, hard-coded candidates, and missing information. Choose **Use as-is**, **Adapt to project**, **Convert to template**, **Extract components**, **Combine**, or a destination type. The source is preserved under `.promptworkspace/imports/`, while the accepted result becomes a new canonical Markdown asset with provenance.

Select an asset to edit it, copy it, add it to a workflow draft, or run it. **Local preview** is deterministic and works offline. Selecting OpenAI, Claude, or Gemini uses the corresponding API adapter if a key has been saved in **Provider settings**. Consumer-interface delivery remains explicit copy/export rather than private-site automation.

## Architecture status

The implementation preserves the approved separation between canonical files, derived index, promptflow/domain services, provider adapters, secure credentials, and UI. The MVP uses a JSON derived index to minimize native dependency and shipping friction; the schema and documentation keep the index interface replaceable by SQLite/FTS5 when profiling shows that repository scale requires it.

Google Drive synchronization, bounded graph execution beyond workflow draft generation, evaluation suites, Git snapshots, and production Windows/Android installers remain planned work in the architecture package. They are not presented by this README as implemented features.

## Tests and validation

The repository contains a Flutter smoke test for the application root. The implementation should be extended with service-level tests for import detection, template conversion, provenance preservation, workflow serialization, provider error normalization, and conflict-safe sync before a production release. The original architecture planning package and expanded acceptance matrix are available in `/home/ubuntu/promptflow-os-plan/` in the development environment.

## Security notes

Never commit provider keys. The app stores them in native secure storage and sends them only to the selected provider endpoint. API responses are normalized into run history, and the project files contain only opaque provider profile references when configured. The current MVP does not add project-content encryption; local device/account security remains the user’s responsibility.
