#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MD Quick Copy"
PROCESS_NAME="MD Quick Copy"
BUNDLE_ID="com.alexfisenkov.MDQuickCopy"
CONFIGURATION="${CONFIGURATION:-Release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/MDQuickCopyCodex}"
PROJECT_PATH="$ROOT_DIR/MDQuickCopy.xcodeproj"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"

usage() {
  echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
}

signing_args() {
  local identity="${MD_QUICK_COPY_CODE_SIGN_IDENTITY:-}"
  local team="${MD_QUICK_COPY_DEVELOPMENT_TEAM:-}"

  if [[ -z "$identity" ]]; then
    identity="$(
      security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
        | head -n 1
    )"
  fi

  if [[ -n "$identity" ]]; then
    printf '%s\n' "CODE_SIGN_STYLE=Manual"
    printf '%s\n' "CODE_SIGN_IDENTITY=$identity"

    if [[ -z "$team" && "$identity" =~ \(([A-Z0-9]{10})\)$ ]]; then
      team="${BASH_REMATCH[1]}"
    fi

    if [[ -n "$team" ]]; then
      printf '%s\n' "DEVELOPMENT_TEAM=$team"
    fi
  else
    printf '%s\n' "CODE_SIGN_STYLE=Manual"
    printf '%s\n' "CODE_SIGN_IDENTITY=-"
  fi
}

build_app() {
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR"
  elif [[ ! -d "$PROJECT_PATH" ]]; then
    echo "xcodegen is required because MDQuickCopy.xcodeproj is missing." >&2
    echo "Install it with: brew install xcodegen" >&2
    exit 1
  fi

  xattr -cr "$ROOT_DIR/App" "$ROOT_DIR/Core" "$ROOT_DIR/PreviewExtension" 2>/dev/null || true
  SIGNING_ARGS=()
  while IFS= read -r arg; do
    SIGNING_ARGS+=("$arg")
  done < <(signing_args)

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme MDQuickCopy \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build \
    "${SIGNING_ARGS[@]}"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --build-only|build)
    build_app
    printf '%s\n' "$APP_BUNDLE"
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 1
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
