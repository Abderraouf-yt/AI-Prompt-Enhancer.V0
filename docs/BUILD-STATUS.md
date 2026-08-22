# Build and validation status

## Passing checks

| Check | Result | Evidence |
|---|---|---|
| Dart formatting | Pass | `dart format lib/main.dart lib/core.dart test/*.dart` |
| Static analysis | Pass with non-fatal style/deprecation infos | `flutter analyze --no-fatal-infos` returned status 0 |
| Service tests | Pass | Import detection, variable extraction, provider assumption detection, URL safety, entitlement boundaries, per-variable run serialization, revision frontmatter preservation |
| Widget smoke test | Pass | Promptflow OS root renders after Inbox/Library/Runs refactor |
| Linux release build | Pass | `build/linux/x64/release/bundle/promptflow_os` |
| Linux launch smoke | Pass | Headless process stayed alive for the 20-second smoke window |
| Android release APK | Pass | `build/app/outputs/flutter-apk/app-release.apk` |

## Current artifacts

The final refactor commit is `8cf0127` on the selected repository. The release artifacts were rebuilt after the refactor.


The Android release artifact is an unsigned release APK suitable for local installation/testing. It is not a Play Store-signed production bundle. The Linux release bundle is a desktop smoke artifact for the current environment.

## Windows

The repository contains the generated Windows Flutter target and `tooling/build_windows.ps1`. A native Windows executable cannot be produced in the current Linux sandbox because Flutter Windows release builds require the Windows/Visual Studio desktop C++ toolchain. Run the PowerShell script on a Windows development machine to produce `build/windows/x64/runner/Release`.

## Android runtime limitation

The Android APK builds successfully, but there is no connected Android device or emulator in the current environment for an install-and-interact test. The test suite and release compilation pass; device-level validation remains a required release-candidate step.

## Monetization boundary

The build includes a local free entitlement gate for URL capture, a Pro explanation at the concrete upgrade moment, and privacy-safe local events. It does not include checkout, accounts, server-authoritative entitlements, or hosted analytics. These are intentionally separate follow-up work.

## Features deliberately not claimed as implemented

The current repository does not claim production Google Drive synchronization, full graph Promptflow execution with bounded loops, Git snapshots, automated evaluation suites, signed Windows packaging, or real-time collaboration. The local-first capture/adaptation/reuse slice is implemented first, and the README reflects this boundary rather than presenting roadmap features as finished.
