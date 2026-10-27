#!/bin/bash
# 构建 PieDrop.app（SwiftPM universal release + 手工 bundle + 签名）
#
# 用法:
#   ./scripts/build-app.sh              开发模式：构建并安装到 /Applications
#   ./scripts/build-app.sh --release    发布模式：产出 dist/PieDrop-<版本>.dmg
#
# 版本号：优先 PIEDROP_VERSION 环境变量（CI 由 tag 注入），其次 git describe，默认 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

RELEASE=0
[ "${1:-}" = "--release" ] && RELEASE=1

VERSION="${PIEDROP_VERSION:-$(git describe --tags --always 2>/dev/null || echo "0.1.0")}"
VERSION="${VERSION#v}"

echo "==> swift build (arm64 + x86_64, release) v$VERSION"
# 两个 triple 分别构建再 lipo 合并：不经过 xcbuild，
# 在只有 Command Line Tools（无完整 Xcode）的机器上也能出 universal binary
swift build -c release --triple arm64-apple-macosx
swift build -c release --triple x86_64-apple-macosx
mkdir -p build/universal
lipo -create \
    ".build/arm64-apple-macosx/release/PieDrop" \
    ".build/x86_64-apple-macosx/release/PieDrop" \
    -output "build/universal/PieDrop"
BIN_DIR="build/universal"

APP="build/PieDrop.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/PieDrop" "$APP/Contents/MacOS/PieDrop"
mkdir -p "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.piedrop.app</string>
    <key>CFBundleName</key>
    <string>PieDrop</string>
    <key>CFBundleExecutable</key>
    <string>PieDrop</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>PieDrop 需要向 Finder 与终端发送 Apple 事件：读取选中的文件、定位 CLI 会话窗口、追加路径。不会读取其他内容。</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>PieDrop 需要辅助功能权限，用于向终端模拟 ⌘V 粘贴文件路径。</string>
</dict>
</plist>
EOF

# 签名身份：本机钥匙串有自建证书则用固定身份（重建不丢 TCC 授权），
# 否则回退 ad-hoc（每次重建二进制变化后需在系统设置重新授权辅助功能）
SIGN_IDENTITY="${PIEDROP_SIGN_IDENTITY:-PieDrop Dev}"
if security find-identity -v -p codesigning 2>/dev/null | grep -qF "\"$SIGN_IDENTITY\""; then
    SIGN_ARGS=(-s "$SIGN_IDENTITY")
else
    echo "warn: no codesigning identity '$SIGN_IDENTITY' in keychain, falling back to ad-hoc signing" >&2
    SIGN_ARGS=(-s -)
fi

codesign --force "${SIGN_ARGS[@]}" "$APP"
echo "built: $(pwd)/$APP ($(lipo -archs "$APP/Contents/MacOS/PieDrop"))"

if [ "$RELEASE" = "1" ]; then
    # 发布模式：打包 DMG（有 create-dmg 用拖拽布局，否则 hdiutil 兜底）
    mkdir -p dist
    DMG="dist/PieDrop-$VERSION.dmg"
    rm -f "$DMG"
    if command -v create-dmg >/dev/null 2>&1; then
        create-dmg \
            --volname "PieDrop" \
            --volicon "Assets/AppIcon.icns" \
            --window-pos 200 120 \
            --window-size 660 380 \
            --icon-size 128 \
            --icon "PieDrop.app" 170 185 \
            --app-drop-link 490 185 \
            "$DMG" "$APP" || true
    fi
    [ -f "$DMG" ] || hdiutil create -volname "PieDrop" -srcfolder "$APP" -ov -format UDZO "$DMG"
    echo "dmg: $(pwd)/$DMG"
else
    # 开发模式：安装到 /Applications（先删旧副本；正在运行的实例不受影响，重启后生效）
    INSTALL="/Applications/PieDrop.app"
    rm -rf "$INSTALL"
    cp -R "$APP" "$INSTALL"
    codesign --force "${SIGN_ARGS[@]}" "$INSTALL" >/dev/null 2>&1 || true
    echo "installed: $INSTALL"
fi
