#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT to an Android SDK installation}"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
flutter pub get
flutter test
flutter build apk --release
printf 'Android APK: %s\n' "$PWD/build/app/outputs/flutter-apk/app-release.apk"
