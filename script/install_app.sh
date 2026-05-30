#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MD Quick Copy"
DEST_APP="/Applications/$APP_NAME.app"
EXTENSION_ID="com.alexfisenkov.MDQuickCopy.PreviewExtension"
OLD_MARKDOWN_EXTENSION_ID="org.sbarex.QLMarkdown.QLExtension"
EXTENSION_PATH="$DEST_APP/Contents/PlugIns/MD Quick Copy Preview Extension.appex"

SOURCE_APP="$("$ROOT_DIR/script/build_and_run.sh" --build-only | tail -n 1)"
SOURCE_EXTENSION_PATH="$SOURCE_APP/Contents/PlugIns/MD Quick Copy Preview Extension.appex"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pluginkit -r "$EXTENSION_PATH" >/dev/null 2>&1 || true
pluginkit -r "$SOURCE_EXTENSION_PATH" >/dev/null 2>&1 || true
rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST_APP"
pluginkit -a "$EXTENSION_PATH"
pluginkit -e use -i "$EXTENSION_ID"
pluginkit -e ignore -i "$OLD_MARKDOWN_EXTENSION_ID" >/dev/null 2>&1 || true
qlmanage -r >/dev/null
qlmanage -r cache >/dev/null

printf '%s\n' "$DEST_APP"
