#!/bin/bash

# install.sh
# Sets up ESPSwift from this repository: builds espswift, ESPSwift's
# command-line tool (in cli/), and runs `espswift setup`, which installs
# ESP-IDF (with EIM, Espressif's ESP-IDF Installation Manager), the Swift
# toolchain and the Xcode template. Running it again installs only what's
# missing and updates the rest.
#
# On macOS, it installs EIM with Homebrew if it's missing, trusting
# Espressif's tap for it, as Homebrew requires. On Linux, install EIM first
# (see README.md).
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

if [ "$(uname)" = Darwin ] && ! command -v eim &>/dev/null && command -v brew &>/dev/null; then
    echo "Installing EIM, Espressif's ESP-IDF Installation Manager, with Homebrew (from Espressif's tap, espressif/eim)..."
    brew tap espressif/eim
    # Homebrew versions without `brew trust` don't ask for it.
    brew trust --formula espressif/eim/eim 2>/dev/null || true
    brew install espressif/eim/eim
fi

echo "Building espswift..."
swift build --package-path "$REPO/cli" --configuration release

# espswift finds the template and the scripts in this repository, and
# installs a copy of itself as ~/.espswift/bin/espswift.
exec "$REPO/cli/.build/release/espswift" setup "$@"
