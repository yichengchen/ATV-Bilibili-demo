#!/usr/bin/env bash
# Build and install the app onto a paired Apple TV over the network.
set -euo pipefail

PROJECT="BilibiliLive"
SCHEME="BilibiliLive"
DEVICE_ID="${DEVICE_ID:-REPLACE_WITH_TV_DEVICE_ID}"
DERIVED_ROOT="${HOME}/Library/Developer/Xcode/DerivedData"
TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"

SKIP_CLEAN=${SKIP_CLEAN:-0}
FIX_PERMS=${FIX_PERMS:-1}
SKIP_DEVICE_CHECK=${SKIP_DEVICE_CHECK:-0}

if [[ "${DEVICE_ID}" == "REPLACE_WITH_TV_DEVICE_ID" ]]; then
  echo "Set DEVICE_ID to your Apple TV device ID (from 'xcrun devicectl list devices')."
  exit 1
fi

echo "[1/4] Checking Apple TV reachability..."
if [[ "${SKIP_DEVICE_CHECK}" == "0" ]]; then
  if ! xcrun devicectl list devices | grep -q "${DEVICE_ID}"; then
    if ! xcrun xcdevice list | grep -q "${DEVICE_ID}"; then
      echo "Device ${DEVICE_ID} not found. Ensure the Apple TV is paired and on the same network (or set SKIP_DEVICE_CHECK=1 to bypass)."
      exit 1
    fi
  fi
else
  echo "Skipping device check (SKIP_DEVICE_CHECK=${SKIP_DEVICE_CHECK})."
fi

if [[ "${SKIP_CLEAN}" == "0" ]]; then
  echo "[2/4] Cleaning DerivedData for ${PROJECT}..."
  rm -rf "${DERIVED_ROOT}/${PROJECT}-"*
else
  echo "[2/4] Skipping DerivedData clean (SKIP_CLEAN=${SKIP_CLEAN})."
fi

latest_dd=$(ls -dt "${DERIVED_ROOT}/${PROJECT}-"*/ 2>/dev/null | head -1)
if [[ "${FIX_PERMS}" == "1" && -n "${latest_dd}" ]]; then
  echo "[2b] Normalizing permissions under ${latest_dd}/SourcePackages ..."
  chmod -R u+rw "${latest_dd}/SourcePackages" || true
fi

echo "[3/4] Building ${SCHEME} for Apple TV..."
# Allow optional overrides for signing without editing the project.
declare -a extra_flags=()
if [[ -n "${TEAM_ID}" ]]; then
  extra_flags+=("DEVELOPMENT_TEAM=${TEAM_ID}")
fi
if [[ -n "${BUNDLE_ID}" ]]; then
  extra_flags+=("PRODUCT_BUNDLE_IDENTIFIER=${BUNDLE_ID}")
fi

if ((${#extra_flags[@]})); then
  xcodebuild -project "${PROJECT}.xcodeproj" \
    -scheme "${SCHEME}" \
    -destination "platform=tvOS,id=${DEVICE_ID}" \
    -allowProvisioningUpdates \
    "${extra_flags[@]}" \
    clean build
else
  xcodebuild -project "${PROJECT}.xcodeproj" \
    -scheme "${SCHEME}" \
    -destination "platform=tvOS,id=${DEVICE_ID}" \
    -allowProvisioningUpdates \
    clean build
fi

echo "[4/4] Installing app to Apple TV..."
latest_dd=$(ls -dt "${DERIVED_ROOT}/${PROJECT}-"*/ 2>/dev/null | head -1)
if [[ -z "${latest_dd}" ]]; then
  echo "DerivedData not found after build."
  exit 1
fi

app_path=$(find "${latest_dd}/Build/Products" -type d -name "${PROJECT}.app" | head -1)
if [[ -z "${app_path}" ]]; then
  echo "App bundle not found under ${latest_dd}."
  exit 1
fi

xcrun devicectl device install app --device "${DEVICE_ID}" "${app_path}"
echo "Install complete."
