#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
RELEASE_DIR="$BUILD_DIR/arm64-apple-macosx/release"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Cosmogony"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/Xcode/Assets.xcassets/AppIcon.appiconset"
TEMP_ICONSET_DIR="$DIST_DIR/$APP_NAME.iconset"
SOURCE_ICON="$ROOT_DIR/../../assets/branding/app-icon-mymind-ios-2024.png"
EXTENSION_ICON_DIR="$ROOT_DIR/../../legacy/chrome-extension/public"
EXECUTABLE_SOURCE="$RELEASE_DIR/CosmogonyApp"
EXECUTABLE_TARGET="$MACOS_DIR/$APP_NAME"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

echo "Building release binary..."
cd "$ROOT_DIR"
swift build -c release

if [[ ! -f "$EXECUTABLE_SOURCE" ]]; then
  echo "Expected executable not found: $EXECUTABLE_SOURCE" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR" "$ZIP_PATH" "$DMG_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "Preparing app icon assets..."
if [[ ! -f "$SOURCE_ICON" ]]; then
  echo "Expected source icon not found: $SOURCE_ICON" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"
rm -rf "$TEMP_ICONSET_DIR"
mkdir -p "$TEMP_ICONSET_DIR"
mkdir -p "$EXTENSION_ICON_DIR"

generate_icon() {
  local size="$1"
  local name="$2"
  local output_path="$3"
  sips -z "$size" "$size" "$SOURCE_ICON" --out "$output_path/$name" >/dev/null
}

generate_icon 16 "icon-16.png" "$EXTENSION_ICON_DIR"
generate_icon 32 "icon-32.png" "$EXTENSION_ICON_DIR"
generate_icon 48 "icon-48.png" "$EXTENSION_ICON_DIR"
generate_icon 128 "icon-128.png" "$EXTENSION_ICON_DIR"

generate_icon 16 "icon_16x16.png" "$ICONSET_DIR"
generate_icon 32 "icon_16x16@2x.png" "$ICONSET_DIR"
generate_icon 32 "icon_32x32.png" "$ICONSET_DIR"
generate_icon 64 "icon_32x32@2x.png" "$ICONSET_DIR"
generate_icon 128 "icon_128x128.png" "$ICONSET_DIR"
generate_icon 256 "icon_128x128@2x.png" "$ICONSET_DIR"
generate_icon 256 "icon_256x256.png" "$ICONSET_DIR"
generate_icon 512 "icon_256x256@2x.png" "$ICONSET_DIR"
generate_icon 512 "icon_512x512.png" "$ICONSET_DIR"
generate_icon 1024 "icon_512x512@2x.png" "$ICONSET_DIR"

for icon_name in \
  icon_16x16.png \
  icon_16x16@2x.png \
  icon_32x32.png \
  icon_32x32@2x.png \
  icon_128x128.png \
  icon_128x128@2x.png \
  icon_256x256.png \
  icon_256x256@2x.png \
  icon_512x512.png \
  icon_512x512@2x.png
do
  cp "$ICONSET_DIR/$icon_name" "$TEMP_ICONSET_DIR/$icon_name"
done

iconutil -c icns "$TEMP_ICONSET_DIR" -o "$RESOURCES_DIR/$APP_NAME.icns"
rm -rf "$TEMP_ICONSET_DIR"

echo "Copying executable..."
cp "$EXECUTABLE_SOURCE" "$EXECUTABLE_TARGET"
chmod +x "$EXECUTABLE_TARGET"
find "$APP_DIR" -name '._*' -delete

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Cosmogony</string>
  <key>CFBundleExecutable</key>
  <string>Cosmogony</string>
  <key>CFBundleIconFile</key>
  <string>Cosmogony</string>
  <key>CFBundleIdentifier</key>
  <string>net.v6582374.cosmogony</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Cosmogony</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Cosmogony needs Apple Events access to read the active tab from supported Chromium browsers.</string>
  <key>NSPasteboardUsageDescription</key>
  <string>Cosmogony reads clipboard text when you trigger the capture-clipboard shortcut.</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

echo "Ad-hoc signing app bundle..."
find "$APP_DIR" -name '._*' -delete
codesign --force --deep --sign - "$APP_DIR"

echo "Creating zip archive..."
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
find "$DIST_DIR" -name '._*' -delete

echo "Creating dmg archive..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "Done."
echo "App bundle: $APP_DIR"
echo "Zip archive: $ZIP_PATH"
echo "DMG archive: $DMG_PATH"
