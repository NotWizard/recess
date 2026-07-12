#!/bin/bash
# 打包 Recess.dmg（用 hdiutil，无需 create-dmg/Xcode）。含 /Applications 软链，支持拖拽安装。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VERSION="${1:-0.1.0}"
APP="$ROOT/build/Recess.app"
DMG="$ROOT/build/Recess-$VERSION.dmg"
STAGE="$ROOT/build/dmg-stage"

if [ ! -d "$APP" ]; then
    echo "未找到 $APP，先运行 scripts/build_app.sh"; exit 1
fi

echo "==> 准备暂存目录"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Recess.app"
ln -s /Applications "$STAGE/Applications"

echo "==> hdiutil 生成压缩 DMG"
hdiutil create \
    -volname "Recess" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG"

rm -rf "$STAGE"
echo "==> 完成: $DMG"
ls -lh "$DMG"
