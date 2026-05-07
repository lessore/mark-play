#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MarkPlay"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/release"
DMG_STAGING_DIR="$RELEASE_DIR/dmg-staging"
DMG_PATH="$RELEASE_DIR/$APP_NAME.dmg"

cd "$ROOT_DIR"

"$ROOT_DIR/script/build_and_run.sh" --build-only

rm -rf "$RELEASE_DIR"
mkdir -p "$DMG_STAGING_DIR"

cp -R "$APP_BUNDLE" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING_DIR"

echo "$DMG_PATH"
