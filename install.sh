#!/bin/bash

# install.sh
# Sets up ESPSwift from this repository: builds espswift, ESPSwift's
# command-line tool (in cli/), and runs `espswift setup`, which installs
# ESP-IDF, the Swift toolchain, the Xcode template and the helper scripts.
# Running it again installs only what's missing and updates the rest.
#
# Building espswift needs Swift 6, which comes with Xcode.
#
# Usage: bash install.sh [espswift setup options]
#   e.g. bash install.sh --no-xcode-template

set -e

REPO="$(cd "$(dirname "$0")" && pwd)"

if ! command -v swift &>/dev/null; then
    echo "Error: Swift wasn't found. Install Xcode (or Swift from swift.org), then run this again." >&2
    exit 1
fi

echo "Building espswift..."
swift build --package-path "$REPO/cli" --configuration release

# espswift finds the template and the scripts in this repository, and
# installs a copy of itself as ~/.espswift/bin/espswift.
exec "$REPO/cli/.build/release/espswift" setup "$@"
