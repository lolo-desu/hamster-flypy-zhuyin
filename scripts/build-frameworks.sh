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

# ---- 补齐 Hamster.xcodeproj 引用的其余框架 ----
FW="$ROOT/work/Hamster/Frameworks"

# librime-sbxlm.xcframework 供独立的 SbxlmKeyboard target 链接（上游原包就是
# 一个完整的 librime 构建加声笔插件）。本工程不含声笔方案，但该 target 的
# Frameworks 阶段只靠它提供 rime_* 符号，因此直接复用刚编好的 librime。
# 注意：不能原样整目录复制——同一内部二进制名 librime.a 会让 Xcode 在
# ProcessXCFramework 阶段判定 "Multiple commands produce"（头文件与静态库
# 产物路径都冲突）。这里把两个 slice 的库改名为 librime-sbxlm.a 后用
# xcodebuild -create-xcframework 重新打包：Info.plist 由 Xcode 工具自己写，
# 结构与下方 boost 桩框架及上游 librime 原包完全同构（后者均已验证可被
# ProcessXCFramework 正确处理并参与链接）；不带 Headers，避免头文件重复产物。
rm -rf "$FW/librime-sbxlm.xcframework"
sbx_stage=$(mktemp -d)
mkdir -p "$sbx_stage/device" "$sbx_stage/sim"
cp "$FW/librime.xcframework/ios-arm64/librime.a" "$sbx_stage/device/librime-sbxlm.a"
cp "$FW/librime.xcframework/ios-arm64_x86_64-simulator/librime.a" "$sbx_stage/sim/librime-sbxlm.a"
xcodebuild -create-xcframework \
  -library "$sbx_stage/device/librime-sbxlm.a" \
  -library "$sbx_stage/sim/librime-sbxlm.a" \
  -output "$FW/librime-sbxlm.xcframework"
rm -rf "$sbx_stage"
# 自检：副本必须真的携带 rime C API 符号，否则问题会拖到 SbxlmKeyboard
# 链接期才暴露（run #4 的教训：ProcessXCFramework 静默不产出库文件）。
nm -g "$FW/librime-sbxlm.xcframework/ios-arm64/librime-sbxlm.a" \
  > "$ROOT/work/sbxlm-symbols.txt"
grep -q '_RimeSetOption' "$ROOT/work/sbxlm-symbols.txt" \
  || { echo 'librime-sbxlm 副本缺少 Rime 符号' >&2; exit 1; }

# boost_atomic/boost_locale 只出现在工程链接阶段：librime 与全部上层源码
# （已逐字核查）没有任何符号引用，空桩静态库即可满足引用且不增加体积。
stub_framework() {
  local name="$1" out="$2"
  local tmp; tmp=$(mktemp -d)
  cat > "$tmp/stub.c" <<EOF
/* Stub: 仅满足工程链接阶段对 ${name} 的引用；应用与 librime 均未引用其符号。 */
void flypy_stub_${name}(void) {}
EOF
  local target dir
  mkdir -p "$tmp/ios-arm64" "$tmp/ios-arm64-simulator" "$tmp/ios-x86_64-simulator"
  for target in arm64-apple-ios15.0 arm64-apple-ios15.0-simulator x86_64-apple-ios15.0-simulator; do
    case $target in
      arm64-apple-ios15.0) dir=ios-arm64 ;;
      arm64-apple-ios15.0-simulator) dir=ios-arm64-simulator ;;
      *) dir=ios-x86_64-simulator ;;
    esac
    xcrun clang -c "$tmp/stub.c" -target "$target" -o "$tmp/$dir/stub.o"
    ar rcs "$tmp/$dir/lib${name}.a" "$tmp/$dir/stub.o"
  done
  mkdir -p "$tmp/ios-arm64_x86_64-simulator"
  lipo -create "$tmp/ios-arm64-simulator/lib${name}.a" \
              "$tmp/ios-x86_64-simulator/lib${name}.a" \
       -output "$tmp/ios-arm64_x86_64-simulator/lib${name}.a"
  xcodebuild -create-xcframework \
    -library "$tmp/ios-arm64/lib${name}.a" \
    -library "$tmp/ios-arm64_x86_64-simulator/lib${name}.a" \
    -output "$out"
  rm -rf "$tmp"
}
stub_framework boost_locale "$FW/boost_locale.xcframework"
stub_framework boost_atomic "$FW/boost_atomic.xcframework"

# 快速失败：工程引用的框架必须全部就位。
for f in boost_atomic boost_filesystem boost_locale boost_regex boost_system \
         libglog libleveldb libmarisa libopencc librime librime-sbxlm libyaml-cpp; do
  [ -d "$FW/$f.xcframework" ] || { echo "缺失框架: $f.xcframework" >&2; exit 1; }
done
