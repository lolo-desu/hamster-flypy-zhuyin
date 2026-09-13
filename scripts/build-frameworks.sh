#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 scripts/prepare.py --frameworks
cd work/LibrimeKit-iOS
make boost BOOST_LIBS=regex,system,filesystem,thread BOOST_PLATFORMS=ios,iossim-both
make deps
make librime
make pack
# Both modules must survive static linking. The release without octagram is
# deliberately not used because it would change Frost's ranking behavior.
nm -g Frameworks/librime.xcframework/ios-arm64/librime.a > "$ROOT/work/rime-symbols.txt"
grep -q 'rime_require_module_lua' "$ROOT/work/rime-symbols.txt"
grep -q 'rime_require_module_octagram' "$ROOT/work/rime-symbols.txt"
cp -R Frameworks/*.xcframework "$ROOT/work/Hamster/Frameworks/"
