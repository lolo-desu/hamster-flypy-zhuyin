#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/work/Hamster"
xcodebuild -version
xcodebuild archive -project Hamster.xcodeproj -scheme Hamster \
  -destination 'generic/platform=iOS' -archivePath "$ROOT/work/Hamster.xcarchive" \
  -derivedDataPath "$ROOT/work/DerivedData" -configuration Release \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' COMPILER_INDEX_STORE_ENABLE=NO
APP="$ROOT/work/Hamster.xcarchive/Products/Applications/Hamster.app"
test -d "$APP/PlugIns/HamsterKeyboard.appex"
mkdir -p "$ROOT/dist/Payload"
ditto "$APP" "$ROOT/dist/Payload/Hamster.app"
# Preserve an unsigned archive: no ad-hoc signing or exportArchive step.
python3 "$ROOT/scripts/check-ipa.py" "$ROOT/dist/Payload/Hamster.app"
cd "$ROOT/dist"
zip -qry Hamster-Flypy-Zhuyin-unsigned.ipa Payload
shasum -a 256 Hamster-Flypy-Zhuyin-unsigned.ipa > SHA256SUMS.txt
cp "$ROOT/upstream.lock.json" .
