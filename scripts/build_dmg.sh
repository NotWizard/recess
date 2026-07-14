#!/bin/bash
# 打包 Recess.dmg（用 hdiutil，无需 create-dmg/Xcode）。含 /Applications 软链，支持拖拽安装。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
VERSION="${1:-0.1.0}"
APP="$ROOT/build/Recess.app"
DMG="$ROOT/build/Recess-$VERSION.dmg"
STAGE="$ROOT/build/dmg-stage"
RW_DMG="$ROOT/build/Recess-rw.dmg"
VOL="Recess"
MOUNT="/Volumes/$VOL"

if [ ! -d "$APP" ]; then
    echo "未找到 $APP，先运行 scripts/build_app.sh"; exit 1
fi

echo "==> 准备暂存目录"
rm -rf "$STAGE" "$DMG" "$RW_DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Recess.app"
ln -s /Applications "$STAGE/Applications"

echo "==> 生成可读写 DMG（临时）"
hdiutil create -ov -volname "$VOL" -fs HFS+ -srcfolder "$STAGE" -format UDRW "$RW_DMG"

echo "==> 挂载并设置 Finder 图标并排布局"
hdiutil detach "$MOUNT" 2>/dev/null || true
hdiutil attach -nobrowse "$RW_DMG" -mountpoint "$MOUNT"
sleep 1
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "Recess"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "Recess.app" of container window to {180, 190}
        set position of item "Applications" of container window to {500, 190}
        close
    end tell
end tell
APPLESCRIPT

echo "==> 卸载并转成只读压缩 DMG"
hdiutil detach "$MOUNT"
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG"

rm -rf "$STAGE" "$RW_DMG"
echo "==> 完成: $DMG"
ls -lh "$DMG"
