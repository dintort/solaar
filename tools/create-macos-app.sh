#!/usr/bin/env bash
# Helper to build a minimal macOS .app wrapper for Solaar.
set -euo pipefail

APP_ROOT=${1:-Solaar.app}
SOLAR_PATH=${SOLAR_PATH:-/opt/homebrew/bin/solaar}
ICON_SOURCE=${ICON_SOURCE:-share/solaar/icons/solaar-light_100.png}

if [[ ! -x "${SOLAR_PATH}" ]]; then
    echo "Error: Unable to execute ${SOLAR_PATH}. Set SOLAR_PATH to the solaar binary." >&2
    exit 1
fi

case "${APP_ROOT}" in
    ""|"/"|".")
        echo "Error: Refusing to create app bundle at unsafe location: \"${APP_ROOT}\"" >&2
        exit 1
        ;;
esac

echo "Creating Solaar app bundle at ${APP_ROOT}"
rm -rf "${APP_ROOT}"

APP_CONTENTS="${APP_ROOT}/Contents"
MACOS_DIR="${APP_CONTENTS}/MacOS"
RESOURCES_DIR="${APP_CONTENTS}/Resources"

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

WRAPPER="${MACOS_DIR}/solaar-wrapper"
cat > "${WRAPPER}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "${SOLAR_PATH}" "\$@"
EOF
chmod +x "${WRAPPER}"

HAVE_ICON=0
if command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1 && [[ -f "${ICON_SOURCE}" ]]; then
    TMP_ICONSET=$(mktemp -d /tmp/solaar-iconset.XXXXXX)
    trap 'rm -rf "${TMP_ICONSET}"' EXIT
    for SIZE in 16 32 64 128 256 512; do
        sips -s format png -z "${SIZE}" "${SIZE}" "${ICON_SOURCE}" --out "${TMP_ICONSET}/icon_${SIZE}x${SIZE}.png" >/dev/null
        DOUBLE=$((SIZE * 2))
        sips -s format png -z "${DOUBLE}" "${DOUBLE}" "${ICON_SOURCE}" --out "${TMP_ICONSET}/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
    done
    if iconutil -c icns "${TMP_ICONSET}" -o "${RESOURCES_DIR}/solaar.icns" >/dev/null 2>&1; then
        HAVE_ICON=1
        echo "Added icon from ${ICON_SOURCE}"
    else
        echo "Warning: Failed to create solaar.icns – continuing without custom icon" >&2
    fi
    rm -rf "${TMP_ICONSET}"
    trap - EXIT
else
    echo "Skipping icon generation (requires sips, iconutil, and ${ICON_SOURCE})"
fi

{
cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>solaar-wrapper</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.pwr-solaar.solaar</string>
    <key>CFBundleName</key>
    <string>Solaar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
EOF
if [[ ${HAVE_ICON} -eq 1 ]]; then
cat <<'EOF'
    <key>CFBundleIconFile</key>
    <string>solaar.icns</string>
EOF
fi
cat <<'EOF'
</dict>
</plist>
EOF
} > "${APP_CONTENTS}/Info.plist"

echo "Solaar app bundle created at ${APP_ROOT}"
echo "Move the bundle to /Applications (or anywhere convenient) and launch it like any other app."
