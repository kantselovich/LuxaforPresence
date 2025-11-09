#!/usr/bin/env bash

set -euo pipefail

CONFIGURATION=release
DMG_NAME=LuxaforPresence

usage() {
    cat <<'EOF'
Usage: package-dmg.sh [-c debug|release] [-n VolumeName]

Builds LuxaforPresence, wraps it in a minimal .app bundle, and produces
dist/LuxaforPresence.dmg (or a custom volume name via -n).
EOF
    exit 1
}

while getopts ":c:n:h" opt; do
    case "${opt}" in
        c) CONFIGURATION="${OPTARG}" ;;
        n) DMG_NAME="${OPTARG}" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [[ $# -ne 0 ]]; then
    usage
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "swift command not found; install Xcode or the CLT." >&2
    exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
    echo "hdiutil command not found; cannot create dmg." >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT_NAME=LuxaforPresence
DIST_DIR="${REPO_ROOT}/dist"
BUILD_DIR="${REPO_ROOT}/.build/${CONFIGURATION}"
APP_DIR="${DIST_DIR}/${PRODUCT_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
DMG_STAGING="${DIST_DIR}/dmg-src"
DMG_PATH="${DIST_DIR}/${DMG_NAME}.dmg"

echo "Building ${PRODUCT_NAME} (${CONFIGURATION})…"
swift build -c "${CONFIGURATION}"

echo "Assembling ${PRODUCT_NAME}.app…"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${REPO_ROOT}/LuxaforPresence/Info.plist" "${CONTENTS_DIR}/Info.plist"
if command -v plutil >/dev/null 2>&1; then
    /usr/bin/plutil -replace CFBundleExecutable -string "${PRODUCT_NAME}" "${CONTENTS_DIR}/Info.plist"
fi
printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

cp "${BUILD_DIR}/${PRODUCT_NAME}" "${MACOS_DIR}/${PRODUCT_NAME}"
chmod +x "${MACOS_DIR}/${PRODUCT_NAME}"

RESOURCE_BUNDLE_PATH="$(find "${BUILD_DIR}" -maxdepth 1 -type d -name "${PRODUCT_NAME}_*.bundle" -print -quit)"
if [[ -n "${RESOURCE_BUNDLE_PATH}" ]]; then
    cp -R "${RESOURCE_BUNDLE_PATH}" "${RESOURCES_DIR}/"
else
    echo "warning: SwiftPM resource bundle not found; UI assets may be missing." >&2
fi

CONFIG_SAMPLE="${REPO_ROOT}/LuxaforPresence/Resources/config.plist"
if [[ -f "${CONFIG_SAMPLE}" ]]; then
    cp "${CONFIG_SAMPLE}" "${RESOURCES_DIR}/config.sample.plist"
fi

echo "Creating dmg at ${DMG_PATH}…"
rm -rf "${DMG_STAGING}" "${DMG_PATH}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_DIR}" "${DMG_STAGING}/"

hdiutil create \
    -volname "${DMG_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" >/dev/null

echo "Done. Mount ${DMG_PATH} to install ${PRODUCT_NAME}.app."
