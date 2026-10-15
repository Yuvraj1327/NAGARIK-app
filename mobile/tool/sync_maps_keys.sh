#!/usr/bin/env bash
# Generates ios/Flutter/MapsKeys.xcconfig (gitignored) from mobile/.env so the
# Google Maps iOS SDK key never has to be hardcoded or committed.
# Usage (from mobile/): tool/sync_maps_keys.sh
set -euo pipefail
cd "$(dirname "$0")/.."
key="${GOOGLE_MAPS_IOS_API_KEY:-$(grep -E '^GOOGLE_MAPS_IOS_API_KEY=' .env | head -1 | cut -d= -f2- | tr -d "\"' ")}"
printf 'GOOGLE_MAPS_IOS_API_KEY=%s\n' "$key" > ios/Flutter/MapsKeys.xcconfig
echo "Wrote ios/Flutter/MapsKeys.xcconfig"
