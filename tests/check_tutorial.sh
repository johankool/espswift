#!/bin/bash

# check_tutorial.sh
# Builds the DocC tutorial (Documentation/ESPSwift.docc) with warnings as
# errors, and checks that the files it starts from are those the template
# creates: Firmware.swift, Blink.swift and BlinkTests.swift of a new
# project from the Blink example (the *-01 files in its Resources), but for
# the "Created by" line. When the template changes them, update the
# tutorial's files to match, and the later steps (-02, -03) too.
#
# Needs Xcode's DocC (macOS). Usage: bash tests/check_tutorial.sh [--output DIR]
#   --output DIR  Where to put the built documentation, for static hosting
#                 (default: a temporary directory).

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$REPO_ROOT/Documentation/ESPSwift.docc"
WORK_DIR=$(mktemp -d -t espswift-tutorial)
OUTPUT="$WORK_DIR/docs"
[ "$1" = "--output" ] && OUTPUT="$2"

echo "Building espswift..."
swift build --package-path "$REPO_ROOT/cli" > "$WORK_DIR/espswift-build.log" 2>&1 \
    || { echo "Building espswift failed; see $WORK_DIR/espswift-build.log"; exit 1; }
"$REPO_ROOT/cli/.build/debug/espswift" new Hello --board esp32-c6-devkitc-1 --example blink \
    --folder "$WORK_DIR" < /dev/null > /dev/null || exit 1

FAILED=false
check() {
    # The tutorial's copy says "Created by you."
    if ! diff <(sed 's|//  Created by .*|//  Created by you.|' "$WORK_DIR/Hello/$1") "$CATALOG/Resources/$2" > /dev/null; then
        echo "The tutorial's $2 differs from a new project's $1:"
        diff <(sed 's|//  Created by .*|//  Created by you.|' "$WORK_DIR/Hello/$1") "$CATALOG/Resources/$2"
        FAILED=true
    fi
}
check Firmware/Firmware.swift Firmware-01.swift
check Packages/HelloKit/Sources/Blink/Blink.swift Blink-01.swift
check Packages/HelloKit/Tests/BlinkTests/BlinkTests.swift BlinkTests-01.swift

echo "Building the tutorial..."
xcrun docc convert "$CATALOG" --fallback-display-name ESPSwift --fallback-bundle-identifier com.espswift.docs \
    --output-path "$OUTPUT" --transform-for-static-hosting --warnings-as-errors || FAILED=true

if [ "$FAILED" = true ]; then
    echo "The tutorial check failed."
    exit 1
fi
echo "The tutorial builds, and starts from the template's files. Built in $OUTPUT"
rm -rf "$WORK_DIR/Hello"
