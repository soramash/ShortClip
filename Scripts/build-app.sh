#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_MODE="${1:-release}"
APP_BUNDLE_PATH="${SHORTCLIP_OUTPUT_APP:-${ROOT_DIR}/dist/ShortClip.app}"
CONTENTS_PATH="${APP_BUNDLE_PATH}/Contents"
MACOS_PATH="${CONTENTS_PATH}/MacOS"

CLANG_MODULE_CACHE_PATH=/tmp/shortclip-clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/shortclip-swiftpm-module-cache \
swift build -c "${BUILD_MODE}" --product ShortClipApp
BIN_PATH="$(CLANG_MODULE_CACHE_PATH=/tmp/shortclip-clang-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/shortclip-swiftpm-module-cache \
  swift build -c "${BUILD_MODE}" --show-bin-path)"
EXECUTABLE_PATH="${BIN_PATH}/ShortClipApp"

rm -rf "${APP_BUNDLE_PATH}"
mkdir -p "${MACOS_PATH}"
cp "${ROOT_DIR}/App/Info.plist" "${CONTENTS_PATH}/Info.plist"
cp "${EXECUTABLE_PATH}" "${MACOS_PATH}/ShortClipApp"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_BUNDLE_PATH}" >/dev/null
fi

echo "Created ${APP_BUNDLE_PATH}"
