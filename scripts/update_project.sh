#!/bin/bash

# update_project.sh
# Brings a project created from an older ESPSwift template up to date with
# the installed ESPSwift. The build warns when a project needs this.
#
# Each step checks the project first, so running it again is safe:
#   1. Replaces the project's build.sh with the template's, which runs
#      ESPSwift's installed build script and carries the template version.
#      (Projects from before that had the whole build script in build.sh,
#      so they never got ESPSwift's fixes.)
#   2. Points the Indexing target, which code completion uses, at the Swift
#      toolchain install.sh installed, e.g. after a Swift upgrade.
#
# It changes the Xcode project, so don't run it while Xcode is building the
# project. If the project is open, Xcode reloads it.
#
# Usage: bash update_project.sh <project_folder>
#   project_folder  The folder with the .xcodeproj (and README.md).

PROJECT_DIR="$1"

if [ -z "$PROJECT_DIR" ]; then
    echo "Usage: bash update_project.sh <project_folder>" >&2
    echo "The project folder is the one with the .xcodeproj in it." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Folder not found: $1" >&2
    exit 1
}

XCODEPROJ=$(ls -d "$PROJECT_DIR"/*.xcodeproj 2>/dev/null | head -1)
if [ -z "$XCODEPROJ" ]; then
    echo "Error: No .xcodeproj in $PROJECT_DIR. Pass the folder that contains it." >&2
    exit 1
fi
PROJECT_NAME="$(basename "$XCODEPROJ" .xcodeproj)"
SOURCE_DIR="$PROJECT_DIR/$PROJECT_NAME"
PBXPROJ="$XCODEPROJ/project.pbxproj"

# The installed template; set ESPSWIFT_TEMPLATE to use another (tests do).
TEMPLATE="${ESPSWIFT_TEMPLATE:-$HOME/Library/Developer/Xcode/Templates/Project Templates/Other/ESP32 RISC-V.xctemplate}"

if [ ! -f "$SOURCE_DIR/CMakeLists.txt" ]; then
    echo "Error: $PROJECT_NAME doesn't look like an ESPSwift project ($SOURCE_DIR/CMakeLists.txt not found)." >&2
    exit 1
fi
if [ ! -f "$TEMPLATE/build.sh" ]; then
    echo "Error: The ESPSwift template isn't installed. Please run install.sh first." >&2
    exit 1
fi

echo "Updating $PROJECT_NAME..."
CHANGED=false

# ── 1. build.sh ──────────────────────────────────────────────────

if ! cmp -s "$TEMPLATE/build.sh" "$SOURCE_DIR/build.sh"; then
    cp "$TEMPLATE/build.sh" "$SOURCE_DIR/build.sh"
    chmod +x "$SOURCE_DIR/build.sh"
    echo "  Replaced build.sh with the template's."
    CHANGED=true
fi

# ── 2. Swift toolchain for code completion ───────────────────────

SWIFT_TOOLCHAIN=$(cat "$HOME/.espswift/swift-toolchain" 2>/dev/null)
if [ -n "$SWIFT_TOOLCHAIN" ] && [ -f "$SWIFT_TOOLCHAIN/Info.plist" ]; then
    TOOLCHAIN_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$SWIFT_TOOLCHAIN/Info.plist")
    # Only the Indexing target sets TOOLCHAINS.
    if grep -q "TOOLCHAINS = " "$PBXPROJ" && grep "TOOLCHAINS = " "$PBXPROJ" | grep -qv "TOOLCHAINS = $TOOLCHAIN_ID;"; then
        sed -i '' "s/\(TOOLCHAINS = \)[^;]*;/\1$TOOLCHAIN_ID;/" "$PBXPROJ"
        echo "  Pointed the Indexing target (code completion) at $(basename "$SWIFT_TOOLCHAIN")."
        CHANGED=true
    elif ! grep -q "TOOLCHAINS = " "$PBXPROJ"; then
        echo "  Note: This project has no Indexing target, so it doesn't get code completion."
        echo "        Projects created from the current template have one."
    fi
fi

if [ "$CHANGED" = true ]; then
    echo "Done."
else
    echo "Already up to date."
fi
