$ErrorActionPreference = 'Stop'

flutter pub get
flutter test
flutter build windows --release
Write-Host "Windows bundle: build/windows/x64/runner/Release"
