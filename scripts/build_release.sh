#!/bin/bash
# Build release AAB with all environment variables from .env

set -e

# Load .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep -v '^$' | xargs)
fi

flutter build appbundle --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=RC_API_KEY_ANDROID="$RC_API_KEY_ANDROID" \
  --dart-define=RC_API_KEY_IOS="$RC_API_KEY_IOS" \
  --dart-define=ADMOB_BANNER_ANDROID="$ADMOB_BANNER_ANDROID" \
  --dart-define=ADMOB_REWARDED_ANDROID="$ADMOB_REWARDED_ANDROID"

echo ""
echo "AAB built: build/app/outputs/bundle/release/app-release.aab"
