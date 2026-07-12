#!/bin/bash
# 构建 Recess.app 应用包（无需 Xcode，使用 SwiftPM + 手工装配 + ad-hoc 签名）。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VERSION="${1:-0.1.0}"
APP="$ROOT/build/Recess.app"

echo "==> swift build (release)"
swift build --product Recess -c release
BIN="$(swift build --product Recess -c release --show-bin-path)/Recess"

echo "==> 测试门禁：引擎断言测试"
swift run RecessTests

echo "==> 测试门禁：GUI 层无界面自检"
"$BIN" --selftest

echo "==> 装配 $APP (version $VERSION)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Recess"
sed "s/__VERSION__/$VERSION/g" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# 图标（若存在）
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" || true

echo "==> 完成: $APP"
