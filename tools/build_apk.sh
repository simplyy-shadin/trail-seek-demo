#!/usr/bin/env bash
# Release APK with the Supabase config applied when supabase.env exists.
set -euo pipefail
cd "$(dirname "$0")/.."
DEFINES=()
if [ -f supabase.env ]; then DEFINES=(--dart-define-from-file=supabase.env); echo "Using supabase.env (cloud mode)"; else echo "No supabase.env: local-only build"; fi
flutter build apk --release --split-per-abi "${DEFINES[@]}" "$@"
ls -la build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
