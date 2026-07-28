#!/usr/bin/env bash
# Vercel Build Command for this project (Project Settings -> Build Command:
# `bash scripts/vercel_build.sh`). Vercel has no Flutter SDK preinstalled, so
# this fetches Flutter, reconstructs .env.json from the project's Environment
# Variables (SUPABASE_URL / SUPABASE_ANON_KEY / SENTRY_DSN), then builds.
set -euo pipefail

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
export PATH="$PATH:$PWD/_flutter/bin"
flutter doctor

printf '{"SUPABASE_URL":"%s","SUPABASE_ANON_KEY":"%s","SENTRY_DSN":"%s"}' \
  "${SUPABASE_URL:-}" "${SUPABASE_ANON_KEY:-}" "${SENTRY_DSN:-}" > .env.json

flutter pub get
flutter build web --release --dart-define-from-file=.env.json
