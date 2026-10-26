#!/bin/bash
# 构建 PieDrop.app（SwiftPM release + 手工 bundle + 签名）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/PieDrop.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PieDrop "$APP/Contents/MacOS/PieDrop"
mkdir -p "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
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
    <string>0.1.0</string>
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
echo "built: $(pwd)/$APP"

# 安装到 /Applications（先删旧副本；正在运行的实例不受影响，重启后生效）
INSTALL="/Applications/PieDrop.app"
rm -rf "$INSTALL"
cp -R "$APP" "$INSTALL"
codesign --force "${SIGN_ARGS[@]}" "$INSTALL" >/dev/null 2>&1 || true
echo "installed: $INSTALL"
