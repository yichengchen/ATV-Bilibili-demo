#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/BilibiliLive.xcodeproj}"
SCHEME="${SCHEME:-BilibiliLive}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"
SIMULATOR_NAME="${SIMULATOR_NAME:-Apple TV}"
APP_NAME="${APP_NAME:-$SCHEME.app}"
BUNDLE_ID="${BUNDLE_ID:-}"
OPEN_SIMULATOR=1

usage() {
  cat <<'EOF'
Usage: scripts/run_simulator.sh [options]

Build, install, and launch the tvOS app in Simulator.

Options:
  --simulator-name <name>    Exact Simulator device name to use.
  --scheme <scheme>          Xcode scheme. Default: BilibiliLive
  --configuration <config>   Build configuration. Default: Debug
  --derived-data-path <dir>  DerivedData path. Default: Xcode default DerivedData
  --skip-open                Do not open the Simulator app window.
  -h, --help                 Show this help message.

Environment overrides:
  PROJECT_PATH
  SCHEME
  CONFIGURATION
  DERIVED_DATA_PATH
  SIMULATOR_NAME
  APP_NAME
  BUNDLE_ID
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --simulator-name)
      SIMULATOR_NAME="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --derived-data-path)
      DERIVED_DATA_PATH="$2"
      shift 2
      ;;
    --skip-open)
      OPEN_SIMULATOR=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

find_device_udid_by_name() {
  local target_name="$1"
  xcrun simctl list devices available | awk -v target="$target_name" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, target " (") == 1) {
        if (match(line, /\(([A-F0-9-]+)\)/)) {
          print substr(line, RSTART + 1, RLENGTH - 2)
          exit
        }
      }
    }
  '
}

find_first_apple_tv_udid() {
  xcrun simctl list devices available | awk '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (index(line, "Apple TV") == 1) {
        if (match(line, /\(([A-F0-9-]+)\)/)) {
          print substr(line, RSTART + 1, RLENGTH - 2)
          exit
        }
      }
    }
  '
}

find_latest_built_app_path() {
  local products_root="$HOME/Library/Developer/Xcode/DerivedData"
  find "$products_root" -path "*/Build/Products/${CONFIGURATION}-appletvsimulator/$APP_NAME" -type d -print 2>/dev/null |
    while IFS= read -r path; do
      printf '%s\t%s\n' "$(stat -f '%m' "$path")" "$path"
    done |
    sort -nr |
    head -n1 |
    cut -f2-
}

simulator_udid="$(find_device_udid_by_name "$SIMULATOR_NAME")"
if [[ -z "$simulator_udid" ]]; then
  simulator_udid="$(find_first_apple_tv_udid)"
fi

if [[ -z "$simulator_udid" ]]; then
  echo "No available Apple TV simulator found." >&2
  exit 1
fi

destination="platform=tvOS Simulator,id=$simulator_udid"

if [[ "$APP_NAME" != *.app ]]; then
  APP_NAME="$APP_NAME.app"
fi

if [[ "$OPEN_SIMULATOR" -eq 1 ]]; then
  open -a Simulator --args -CurrentDeviceUDID "$simulator_udid" >/dev/null 2>&1 || open -a Simulator >/dev/null 2>&1 || true
fi

echo "Using simulator: $SIMULATOR_NAME ($simulator_udid)"
xcrun simctl boot "$simulator_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator_udid" -b

build_command=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$destination"
  build
)

if [[ -n "$DERIVED_DATA_PATH" ]]; then
  build_command+=(-derivedDataPath "$DERIVED_DATA_PATH")
fi

echo "Building $SCHEME ($CONFIGURATION)..."
"${build_command[@]}"

if [[ -n "$DERIVED_DATA_PATH" ]]; then
  app_path="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-appletvsimulator/$APP_NAME"
else
  app_path="$(find_latest_built_app_path)"
fi

if [[ -z "$app_path" || ! -d "$app_path" ]]; then
  echo "Built app not found at: $app_path" >&2
  exit 1
fi

if [[ -z "$BUNDLE_ID" ]]; then
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"
fi

if [[ -z "$BUNDLE_ID" ]]; then
  echo "Failed to resolve CFBundleIdentifier from: $app_path/Info.plist" >&2
  exit 1
fi

echo "Installing $app_path"
xcrun simctl terminate "$simulator_udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$simulator_udid" "$app_path"

echo "Launching $BUNDLE_ID"
xcrun simctl launch "$simulator_udid" "$BUNDLE_ID"
