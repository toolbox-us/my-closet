#!/usr/bin/env bash
#
# Generates the platform folders (android/, ios/) this project needs and
# installs dependencies.
#
# Why this exists: the project ships only source (lib/, test/, assets/,
# pubspec.yaml). Platform scaffolding is machine- and SDK-version-specific,
# so it is generated locally rather than committed.
#
# IMPORTANT: this script never touches lib/, test/, assets/ or pubspec.yaml.
# It generates a throwaway Flutter project in a temp directory and copies
# only the platform folders across. Running `flutter create .` directly in
# here would risk overwriting lib/main.dart.
#
# Usage:  cd my_closet && ./setup.sh
#         (on Windows, run this from Git Bash, or follow the manual steps
#          in README.md)

set -euo pipefail

PROJECT_NAME="my_closet"
ORG="com.example"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "==> Checking for Flutter"
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter is not on your PATH."
  echo "Install it from https://docs.flutter.dev/get-started/install and"
  echo "make sure 'flutter --version' works, then run this again."
  exit 1
fi
flutter --version | head -n 1

if [[ ! -f pubspec.yaml ]]; then
  echo "ERROR: run this from inside the my_closet folder (no pubspec.yaml here)."
  exit 1
fi

echo
echo "==> Generating platform folders"
if [[ -d android ]]; then
  echo "    android/ already exists - leaving it alone."
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  flutter create \
    --project-name "$PROJECT_NAME" \
    --org "$ORG" \
    --platforms=android,ios \
    "$tmp/shell" >/dev/null

  cp -R "$tmp/shell/android" ./android
  echo "    created android/"

  if [[ -d "$tmp/shell/ios" ]]; then
    cp -R "$tmp/shell/ios" ./ios
    echo "    created ios/"
  fi
fi

echo
echo "==> Installing dependencies"
flutter pub get

echo
echo "==> Running the analyzer"
flutter analyze || echo "    (analyzer reported issues - see output above)"

echo
echo "==> Running tests"
flutter test || echo "    (some tests failed - see output above)"

echo
echo "============================================================"
echo "Done."
echo
echo "Open this folder in Android Studio, pick a device, and Run."
echo
echo "To enable real Gemini analysis, run with your own key:"
echo
echo "  flutter run \\"
echo "    --dart-define=GEMINI_API_KEY=YOUR_KEY \\"
echo "    --dart-define=GEMINI_MODEL=gemini-3.8-flash"
echo
echo "Without a key the app still runs; AI analysis returns a clearly"
echo "labelled example instead. See README.md."
echo "============================================================"
