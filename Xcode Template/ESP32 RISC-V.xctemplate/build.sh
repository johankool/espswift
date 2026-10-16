#!/bin/bash

# build.sh
# Run by Xcode when you press Build (Cmd+B) or Clean: builds this project
# with espswift, ESPSwift's command-line tool (`espswift build`).
#
# espswift setup links espswift at ~/.espswift/bin/espswift, so updating
# ESPSwift updates the build of this project too. Set ESPSWIFT_BIN to use
# another espswift.

# The version of the ESPSwift template this project's files match. When
# ESPSwift needs projects to change, the build warns about older projects;
# `espswift update` updates them.
export ESPSWIFT_PROJECT_VERSION=1

ESPSWIFT_BIN="${ESPSWIFT_BIN:-$HOME/.espswift/bin/espswift}"

if [ ! -x "$ESPSWIFT_BIN" ]; then
    echo "error: espswift wasn't found at $ESPSWIFT_BIN. Install ESPSwift, then run: espswift setup"
    exit 1
fi

# Build in the folder this script is in: the project's source folder.
cd "$(dirname "$0")" || exit 1
exec "$ESPSWIFT_BIN" build "$@"
