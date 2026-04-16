#!/bin/bash

# Configuration
APP_NAME="Myrics"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MAC_OS_DIR="${CONTENTS_DIR}/MacOS"

# Clean previous builds completely
echo "Cleaning old app bundle..."
rm -rf "${APP_DIR}"

# Create directory structure
echo "Creating bundle structure..."
mkdir -p "${MAC_OS_DIR}"

# Write Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Myrics</string>
    <key>CFBundleIdentifier</key>
    <string>com.tamohar.Myrics</string>
    <key>CFBundleName</key>
    <string>Myrics</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Myrics requires access to Spotify to retrieve playback status.</string>
</dict>
</plist>
EOF

# Compile
echo "Compiling swift files..."
swiftc -framework AppKit src/*.swift -o "${MAC_OS_DIR}/Myrics"

if [ $? -eq 0 ]; then
    echo "Successfully built ${APP_NAME}.app!"
else
    echo "Compilation failed."
    exit 1
fi
