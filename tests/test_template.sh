#!/bin/bash

# test_template.sh
# Creates projects from the Xcode template and builds them, to check that
# the template works for every chip it offers.
#
# Each project is created with `espswift new`, which lays it out the way
# Xcode lays out a new project, using the template's TemplateInfo.plist:
# every file goes to the place its definition names, with Xcode's
# placeholders (___PROJECTNAME___, ___VARIABLE_chip___, ...) filled in. The
# project is then built with its own build.sh, without flashing
# (ESPSWIFT_BUILD_ONLY=1), with espswift built from this repository. Finally the project's Indexing target, which
# Xcode uses for code completion, is built with xcodebuild, using the
# template's settings for it and an Xcode project from tests/fixtures.
# For the first chip, the build is also checked to report a Swift error
# and a CMake error as Xcode issues, with their file and line, and the Swift
# package's tests are run on the Mac with swift test.
#
# Builds use the ESP-IDF and Swift toolchain that install.sh installed, so
# run install.sh first. Each chip is a full ESP-IDF build of a few minutes.
#
# Without Xcode (on Linux), only the builds, their error reporting and the
# Kit package's tests are checked.
#
# With --examples, it tests the example projects in Examples/ instead: each
# is copied, built, and checked the same way (except the error reporting),
# its Kit package's tests run, and its Xcode project must be the one
# tests/xcode_project.py writes for it. Their builds must have no warnings
# (other than those `espswift update` resolves).
#
# Not covered: Xcode itself (how it shows the template, fills in the
# placeholders and indexes), flashing, and running on a board.
#
# Usage: bash tests/test_template.sh [--keep] [--work-dir DIR] [--examples] [name ...]
#   name            One or more chips of the template's boards, e.g.
#                   esp32c6, or with --examples, examples, e.g. DeepSleep.
#                   Default: all of them.
#   --examples      Test the examples in Examples/ instead of the template.
#   --keep          Keep the generated projects and build logs. They are
#                   always kept when a build fails, or with --work-dir.
#   --work-dir DIR  Where to create the projects and logs (<name>.log).
#                   Default: a new temporary directory.

KEEP=false
EXAMPLES=false
WORK_DIR=""
ITEMS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --keep) KEEP=true ;;
        --examples) EXAMPLES=true ;;
        --work-dir)
            WORK_DIR="$2"
            shift
            ;;
        -h|--help)
            # Print the comment block at the top of this file.
            awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *) ITEMS+=("$1") ;;
    esac
    shift
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/Xcode Template/ESP32 RISC-V.xctemplate"
PROJECT_NAME="TemplateTest"

# The chips the template offers: those of the boards in its Board pop-up.
ALL_CHIPS=($(python3 -c '
import plistlib, sys
plist = plistlib.load(open(sys.argv[1], "rb"))
board = next(o for o in plist["Options"] if o["Identifier"] == "board")
chips = [board["Variables"][value]["chip"] for value in board["Values"]]
print(" ".join(dict.fromkeys(chips)))
' "$TEMPLATE/TemplateInfo.plist")) || exit 1

# The examples: the folders in Examples/ with a project of the same name.
ALL_EXAMPLES=()
for dir in "$REPO_ROOT"/Examples/*/; do
    name=$(basename "$dir")
    [ -d "$dir/$name.xcodeproj" ] && ALL_EXAMPLES+=("$name")
done

if [ "$EXAMPLES" = true ]; then
    ALL_ITEMS=("${ALL_EXAMPLES[@]}")
    KIND="example"
else
    ALL_ITEMS=("${ALL_CHIPS[@]}")
    KIND="chip"
fi
if [ ${#ITEMS[@]} -eq 0 ]; then
    ITEMS=("${ALL_ITEMS[@]}")
fi

for ITEM in "${ITEMS[@]}"; do
    if [[ ! " ${ALL_ITEMS[*]} " =~ " $ITEM " ]]; then
        echo "Error: '$ITEM' is not one of the ${KIND}s (${ALL_ITEMS[*]})." >&2
        exit 1
    fi
done

if [ -n "$WORK_DIR" ]; then
    mkdir -p "$WORK_DIR" && WORK_DIR="$(cd "$WORK_DIR" && pwd)" || exit 1
else
    WORK_DIR=$(mktemp -d -t espswift-template-test)
    CREATED_WORK_DIR=true
fi
# Projects build with espswift (their build.sh runs `espswift build`); use
# this repository's, built here, unless ESPSWIFT_BIN names another.
if [ -z "$ESPSWIFT_BIN" ]; then
    echo "Building espswift..."
    swift build --package-path "$REPO_ROOT/cli" > "$WORK_DIR/espswift-build.log" 2>&1 \
        || { echo "Building espswift failed; see $WORK_DIR/espswift-build.log"; exit 1; }
    ESPSWIFT_BIN="$REPO_ROOT/cli/.build/debug/espswift"
fi
export ESPSWIFT_BIN

if [ "$EXAMPLES" = true ]; then
    echo "Testing the examples: ${ITEMS[*]}"
else
    echo "Testing the template for: ${ITEMS[*]}"
fi
echo "Working directory: $WORK_DIR"

# Creates a project for a chip in $WORK_DIR/<chip> with `espswift new`,
# which lays it out as Xcode does and fails if a placeholder is left unfilled.
create_project() {
    local parent="$WORK_DIR/.new-$1"
    rm -rf "$parent" && mkdir -p "$parent"
    "$ESPSWIFT_BIN" new "$PROJECT_NAME" --chip "$1" --folder "$parent" > /dev/null \
        && mv "$parent/$PROJECT_NAME" "$WORK_DIR/$1" && rm -rf "$parent"
}

# Copies an example to $WORK_DIR/<example>, without what its builds left
# in the repository's copy.
copy_example() {
    rm -rf "$WORK_DIR/$1" && mkdir -p "$WORK_DIR/$1" || return 1
    tar -C "$REPO_ROOT/Examples/$1" -cf - --exclude build --exclude .build --exclude .swiftpm \
        --exclude .espswift --exclude managed_components --exclude sdkconfig --exclude sdkconfig.old \
        --exclude xcuserdata . | tar -C "$WORK_DIR/$1" -xf -
}

# Checks an example's Xcode project is the one tests/xcode_project.py
# writes for it: with the template's current settings and the example's
# files.
check_example_xcode_project() {
    python3 "$REPO_ROOT/tests/xcode_project.py" --check "$REPO_ROOT/Examples/$1"
}

# Checks the build had no warnings, other than those that `espswift update`
# resolves in a project that wasn't created on this Mac.
check_no_warnings() {
    local warnings
    warnings=$(grep "warning:" "$2" | grep -v -e "Code completion uses another Swift toolchain" \
        -e "The Run scheme (Cmd+R) doesn't know where espswift is")
    if [ -n "$warnings" ]; then
        echo "The build of $1 has warnings:"
        echo "$warnings"
        return 1
    fi
}

# Adds an Xcode project to the generated project, as Xcode would create it
# from the template. Only Xcode can create one from a template, so this is
# a project Xcode created (tests/fixtures/project.pbxproj); check_indexing
# applies the template's current Indexing settings on top of it.
add_xcode_project() {
    local xcodeproj="$WORK_DIR/$1/$PROJECT_NAME.xcodeproj"
    mkdir -p "$xcodeproj/xcshareddata/xcschemes"
    sed "s/___PROJECTNAME___/$PROJECT_NAME/g" "$REPO_ROOT/tests/fixtures/project.pbxproj" > "$xcodeproj/project.pbxproj"
    # The template's Run scheme, which Xcode puts in the Xcode project.
    sed "s/___PROJECTNAME___/$PROJECT_NAME/g" "$TEMPLATE/scheme.xcscheme" \
        > "$xcodeproj/xcshareddata/xcschemes/$PROJECT_NAME.xcscheme"
}

# Builds the Indexing target with xcodebuild, the way Xcode's indexer
# compiles it: with the Indexing target's settings from TemplateInfo.plist
# and the include-paths.rsp build.sh generated. Checks it compiles exactly the
# Swift files of the Firmware target, as SwiftPM built it.
check_indexing() {
    python3 - "$TEMPLATE" "$WORK_DIR/$1" "$PROJECT_NAME" <<'EOF'
import json, os, plistlib, shutil, subprocess, sys

template, project_dir, name = sys.argv[1:]
plist = plistlib.load(open(os.path.join(template, "TemplateInfo.plist"), "rb"))
target = next(t for t in plist["Targets"] if t.get("Name") == "Indexing")

# Xcode only indexes files that belong to the Indexing target, which the
# template declares per file with the target's identifier: the firmware's
# Swift files, but not its Package.swift. (Xcode indexes the Kit package
# itself, for the Mac.)
for node, definition in plist["Definitions"].items():
    indexed = target.get("TargetIdentifier") in definition.get("TargetIdentifiers", [])
    if node.endswith(".swift") and indexed != (node.startswith("Firmware/") and not node.endswith("Package.swift")):
        relation = "belongs" if indexed else "doesn't belong"
        sys.exit(f"{node} {relation} to the Indexing target ({target.get('TargetIdentifier')}).")

source_dir = os.path.join(project_dir, name)
for generated in (".espswift/include-paths.rsp",):
    if not os.path.exists(os.path.join(source_dir, generated)):
        sys.exit(f"Missing {generated}: espswift build didn't set up code completion.")

# install.sh replaces the toolchain placeholder with the identifier of the
# Swift toolchain it installed; do the same with the toolchain the build used.
if target["SharedSettings"].get("TOOLCHAINS") != "ESPSWIFT_SWIFT_TOOLCHAIN_ID":
    sys.exit("The Indexing target's TOOLCHAINS must be ESPSWIFT_SWIFT_TOOLCHAIN_ID, which install.sh replaces.")
toolchain = os.environ.get("ESPSWIFT_TOOLCHAIN") or open(os.path.expanduser("~/.espswift/swift-toolchain")).read().strip()
toolchain_id = plistlib.load(open(os.path.join(toolchain, "Info.plist"), "rb"))["CFBundleIdentifier"]

# The template's settings go into the Indexing target, as Xcode puts them
# there when it creates a project. (On xcodebuild's command line, they would
# apply to everything it builds, including the Kit package's manifest.)
# Xcode reads a project file in XML too. This is done in a copy of the
# project next to it, so the other checks see the project as created.
xcodeproj = os.path.join(project_dir, "IndexingCheck.xcodeproj")
shutil.rmtree(xcodeproj, ignore_errors=True)
shutil.copytree(os.path.join(project_dir, name + ".xcodeproj"), xcodeproj)
pbxproj = os.path.join(xcodeproj, "project.pbxproj")
project = plistlib.loads(subprocess.run(["plutil", "-convert", "xml1", "-o", "-", pbxproj],
                                        capture_output=True, check=True).stdout)
objects = project["objects"]
indexing = next(o for o in objects.values() if o.get("isa") == "PBXNativeTarget" and o.get("name") == "Indexing")
for configuration in objects[indexing["buildConfigurationList"]]["buildConfigurations"]:
    objects[configuration]["buildSettings"] = {
        key: value.replace("___PROJECTNAME___", name).replace("ESPSWIFT_SWIFT_TOOLCHAIN_ID", toolchain_id)
        for key, value in target["SharedSettings"].items()}
with open(pbxproj, "wb") as f:
    plistlib.dump(project, f)

output = os.path.join(project_dir, "xcodebuild")
build_dirs = ["SYMROOT=" + os.path.join(output, "Products"), "OBJROOT=" + os.path.join(output, "Intermediates")]

# Xcode also builds the Kit package, for the Mac, into the same build
# folder. The Indexing target must not import the Mac's modules from there.
kit = subprocess.run(["xcodebuild", "-project", xcodeproj, "-scheme", "Blink", "-destination", "platform=macOS",
                      *build_dirs, "build"], capture_output=True, text=True)
if kit.returncode != 0:
    sys.exit("Building the Kit package for the Mac failed:\n" + "\n".join((kit.stdout + kit.stderr).splitlines()[-20:]))

result = subprocess.run(["xcodebuild", "-project", xcodeproj,
                         "-target", "Indexing", "-configuration", "Debug", *build_dirs, "build"],
                        capture_output=True, text=True)
# Other scripts take the first .xcodeproj in the project folder.
shutil.rmtree(xcodeproj)
if result.returncode != 0:
    # xcodebuild reports compile errors on stdout and problems with the
    # project itself (e.g. one it can't open) on stderr.
    output = (result.stdout + "\n" + result.stderr).splitlines()
    errors = [line for line in output if "error:" in line]
    sys.exit("Building the Indexing target failed:\n" + "\n".join(errors[:20] or output[-20:]))

# The Swift files the Indexing target compiled, and those SwiftPM compiled
# for the Firmware target (its sources file, in SwiftPM's working folder).
file_lists = [os.path.join(root, f) for root, _, files in os.walk(output)
              for f in files if f == "Indexing.SwiftFileList"]
indexed = {os.path.realpath(line.strip()) for line in open(file_lists[0]) if line.strip()}
sources = [os.path.join(root, f) for root, _, files in os.walk(project_dir)
           for f in files if f == "sources" and root.endswith("/release/Firmware.build")]
if not sources:
    sys.exit("SwiftPM's list of the Firmware target's sources wasn't found.")
compiled = {os.path.realpath(line.strip()) for line in open(sources[0]) if line.strip()}
if indexed != compiled:
    sys.exit(f"The Indexing target compiles {sorted(indexed)}, but SwiftPM compiled {sorted(compiled)}.")
EOF
}

# Checks that the template's Run scheme resolves to the project's build
# target. Its target identifier is a placeholder (Xcode only assigns the
# real one when it creates the project), so Xcode finds the target by name.
# The scheme is checked under a name of its own, as Xcode also creates an
# automatic scheme named after the target.
check_scheme() {
    local schemes="$WORK_DIR/$1/$PROJECT_NAME.xcodeproj/xcshareddata/xcschemes"
    if [ ! -f "$schemes/$PROJECT_NAME.xcscheme" ]; then
        echo "The template's Run scheme wasn't created in $schemes."
        return 1
    fi
    cp "$schemes/$PROJECT_NAME.xcscheme" "$schemes/TemplateRunScheme.xcscheme"
    xcodebuild -project "$WORK_DIR/$1/$PROJECT_NAME.xcodeproj" -scheme TemplateRunScheme -showBuildSettings 2>&1 \
        | grep -q "and target $PROJECT_NAME:" \
        || { echo "The template's Run scheme doesn't resolve to the $PROJECT_NAME target."; return 1; }
}

# Checks `espswift update` on the project: the test project's
# Indexing target names a placeholder toolchain, so the first run must point
# it at the installed one, and a second run must find nothing to update.
check_update() {
    local update=(env ESPSWIFT_TEMPLATE="$TEMPLATE" "$ESPSWIFT_BIN" update --project "$WORK_DIR/$1")
    # The output is read once update is done: grep -q stops reading at the
    # first match, which would stop update before it's done.
    local output
    output=$("${update[@]}")
    echo "$output" | grep -q "Pointed the Indexing target" \
        || { echo "espswift update didn't update the Indexing target's toolchain."; return 1; }
    output=$("${update[@]}")
    echo "$output" | grep -q "Already up to date" \
        || { echo "espswift update changed the project again on a second run:"; echo "$output"; return 1; }
}

# Checks that build errors reach Xcode as issues that jump to their line
# (see cli/Sources/EspSwiftCore/BuildOutputFilter.swift): breaks the Swift code, then the main
# component's CMakeLists.txt, and looks for each error as a "file:line:
# error:" line in the build output. Each file is restored afterwards.
check_diagnostics() {
    local project_dir="$WORK_DIR/$1"
    local source_dir="$project_dir/$PROJECT_NAME"
    local file line output

    for file in "$project_dir/Firmware/Firmware.swift" "$source_dir/main/CMakeLists.txt"; do
        cp "$file" "$file.orig"
        case "$file" in
            *.swift) echo 'let notANumber: Int = "text"' >> "$file" ;;
            *) echo 'no_such_cmake_command()' >> "$file" ;;
        esac
        line=$(wc -l < "$file" | tr -d ' ')
        output=$(cd "$source_dir" && ESPSWIFT_BUILD_ONLY=1 \
            PROJECT_DIR="$project_dir" PROJECT_NAME="$PROJECT_NAME" ./build.sh 2>&1)
        mv "$file.orig" "$file"

        # Compilers name the file by its real path (/private/var/... for a
        # temporary directory); CMake can name it as given.
        local real="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
        if ! echo "$output" | grep -F -e "$file:$line:" -e "$real:$line:" | grep -q ": error: "; then
            echo "The build didn't report the error on line $line of $file as an Xcode issue. Its output:"
            echo "$output" | tail -20
            return 1
        fi
    done
}

# Runs the Kit package's tests with swift test (on the Mac, or Linux).
check_package_tests() {
    local kit="$WORK_DIR/$1/Packages/${PROJECT_NAME}Kit"
    (cd "$kit" && swift test 2>&1) | tail -5
    [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "swift test failed in $kit."; return 1; }
}

# Runs the Kit package's tests with the Test action of the template's scheme
# (Cmd+U in Xcode), which check_scheme copied to TemplateRunScheme.
check_scheme_tests() {
    xcodebuild test -project "$WORK_DIR/$1/$PROJECT_NAME.xcodeproj" -scheme TemplateRunScheme \
        -destination "platform=macOS" -derivedDataPath "$WORK_DIR/$1/xcodebuild-test" 2>&1 | tail -5
    [ "${PIPESTATUS[0]}" -eq 0 ] || { echo "The scheme's Test action (Cmd+U) failed."; return 1; }
}

# Whether a project gets the checks that don't depend on the chip: the first
# chip's, and every example's (each has tests of its own).
is_first_or_example() {
    [ "$EXAMPLES" = true ] || [ "$1" = "${ITEMS[0]}" ]
}

# The checks of the Xcode project, with Xcode (macOS only): code completion,
# the Run scheme, espswift update, and for the first chip and the examples
# Cmd+U.
check_xcode() {
    check_indexing "$1" && check_scheme "$1" && check_update "$1" \
        && { ! is_first_or_example "$1" || check_scheme_tests "$1"; }
}

# Without Xcode (on Linux), projects have no Xcode project, so only the
# build, its error reporting and the Kit's tests are checked.
if command -v xcodebuild > /dev/null 2>&1; then
    WITH_XCODE=true
else
    WITH_XCODE=false
    echo "Xcode wasn't found: checking the builds, error reporting and the Kit's tests only."
fi

FAILED=()

for ITEM in "${ITEMS[@]}"; do
    echo ""
    echo "================================================="
    echo " $ITEM"
    echo "================================================="

    LOG="$WORK_DIR/$ITEM.log"
    # An example's project is named after it.
    if [ "$EXAMPLES" = true ]; then
        PROJECT_NAME="$ITEM"
    fi
    SOURCE_DIR="$WORK_DIR/$ITEM/$PROJECT_NAME"

    if [ "$EXAMPLES" = true ]; then
        if ! check_example_xcode_project "$ITEM" || ! copy_example "$ITEM"; then
            FAILED+=("$ITEM")
            continue
        fi
    else
        if ! create_project "$ITEM"; then
            FAILED+=("$ITEM")
            continue
        fi
        if [ "$WITH_XCODE" = true ]; then
            add_xcode_project "$ITEM"
        fi
    fi

    # Build the way Xcode does (which sets PROJECT_DIR and PROJECT_NAME),
    # but without flashing. TARGET_TEMP_DIR is left unset, so the build
    # output goes to the project's build/ folder.
    START=$(date +%s)
    if (cd "$SOURCE_DIR" && ESPSWIFT_BUILD_ONLY=1 \
            PROJECT_DIR="$WORK_DIR/$ITEM" PROJECT_NAME="$PROJECT_NAME" ./build.sh) > "$LOG" 2>&1 \
        && [ -f "$SOURCE_DIR/build/$PROJECT_NAME.bin" ]; then
        # The error check builds twice more, and the package's tests don't
        # depend on the chip, so they run for the first chip only (and for
        # every example, which has tests of its own).
        if { [ "$EXAMPLES" = false ] || check_no_warnings "$ITEM" "$LOG"; } \
            && { [ "$WITH_XCODE" = false ] || check_xcode "$ITEM" >> "$LOG" 2>&1; } \
            && { [ "$EXAMPLES" = true ] || [ "$ITEM" != "${ITEMS[0]}" ] || check_diagnostics "$ITEM" >> "$LOG" 2>&1; } \
            && { ! is_first_or_example "$ITEM" || check_package_tests "$ITEM" >> "$LOG" 2>&1; }; then
            echo "Passed in $(( $(date +%s) - START ))s: $(grep -m1 "^$PROJECT_NAME.bin binary size" "$LOG")"
        else
            echo "Built, but a check failed. Last lines of $LOG:"
            tail -20 "$LOG"
            FAILED+=("$ITEM")
        fi
    else
        echo "Failed after $(( $(date +%s) - START ))s. Last lines of $LOG:"
        tail -20 "$LOG"
        FAILED+=("$ITEM")
    fi
done

echo ""
echo "================================================="
if [ ${#FAILED[@]} -eq 0 ]; then
    echo " All ${#ITEMS[@]} ${KIND}(s) passed: ${ITEMS[*]}"
    echo "================================================="
    # Only a temporary directory this script created is removed; a
    # --work-dir directory is left as it is.
    if [ "$KEEP" = false ] && [ "$CREATED_WORK_DIR" = true ]; then
        rm -rf "$WORK_DIR"
    else
        echo "Projects and logs kept in $WORK_DIR"
    fi
    exit 0
else
    echo " Failed: ${FAILED[*]}"
    echo "================================================="
    echo "Projects and logs kept in $WORK_DIR"
    exit 1
fi
