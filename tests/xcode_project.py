#!/usr/bin/env python3

# xcode_project.py
# Writes the Xcode project of a project that wasn't created by Xcode, such
# as the examples in Examples/: what Xcode would create from the template,
# for the project's own files.
#
# Only Xcode creates projects from the template, so this starts from a
# project Xcode created (tests/fixtures/project.pbxproj) and applies:
#   - the project's name;
#   - the template's settings for the Indexing target (code completion),
#     with its placeholder toolchain, which `espswift update` fills in;
#   - the Swift files in Firmware/, in the Indexing target;
#   - the template's Run scheme, with espswift's path as a placeholder,
#     which `espswift update` fills in too, and the Kit package's test
#     targets in its Test action (Cmd+U).
#
# Usage: python3 tests/xcode_project.py [--check] PROJECT_DIR...
#   PROJECT_DIR  A project folder, such as Examples/ButtonInput; the project
#                is named after it.
#   --check      Don't write anything; fail if a project's Xcode project
#                differs from what this script writes (e.g. after a change
#                to the template or a new file in Firmware/).

import os
import plistlib
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(REPO_ROOT, "Xcode Template", "ESP32 RISC-V.xctemplate")
FIXTURE = os.path.join(REPO_ROOT, "tests", "fixtures", "project.pbxproj")

# The fixture's Swift files in Firmware/, in the template's order, with the
# identifiers of their file reference and build file.
FIXTURE_FILES = {
    "Firmware.swift": ("C783649930803249000D72CC", "C78364A330803249000D72CC"),
    "Board.swift": ("C78364B030803249000D72CC", "C78364B130803249000D72CC"),
    "LED.swift": ("C78364B230803249000D72CC", "C78364B330803249000D72CC"),
    "FreeRTOS.swift": ("C78364B430803249000D72CC", "C78364B530803249000D72CC"),
}
PACKAGE_SWIFT = "C783649A30803249000D72CC"
# Identifiers for other files: C78364C030803249000D72CC and up.
NEW_ID = "C78364{:02X}30803249000D72CC"


def quoted(value):
    """A value as Xcode writes it in a project file."""
    if re.fullmatch(r"[A-Za-z0-9_./]+", value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def indexing_settings(name):
    """The Indexing target's build settings, as Xcode writes them."""
    plist = plistlib.load(open(os.path.join(TEMPLATE, "TemplateInfo.plist"), "rb"))
    target = next(t for t in plist["Targets"] if t.get("Name") == "Indexing")
    settings = dict(target["SharedSettings"], CODE_SIGN_STYLE="Automatic")
    lines = []
    for key in sorted(settings):
        value = settings[key].replace("___PROJECTNAME___", name)
        if key == "EXCLUDED_SOURCE_FILE_NAMES":
            # Xcode makes a list of it, at the spaces.
            lines.append(f"\t\t\t\t{key} = (")
            lines += [f"\t\t\t\t\t{quoted(item)}," for item in value.split()]
            lines.append("\t\t\t\t);")
        else:
            lines.append(f"\t\t\t\t{key} = {quoted(value)};")
    return "\n".join(lines)


def firmware_files(project_dir):
    """The Swift files in Firmware/ (not its Package.swift), in the
    template's order, then the others by name."""
    folder = os.path.join(project_dir, "Firmware")
    names = [n for n in os.listdir(folder) if n.endswith(".swift") and n != "Package.swift"]
    return [n for n in FIXTURE_FILES if n in names] + sorted(n for n in names if n not in FIXTURE_FILES)


def pbxproj(project_dir, name):
    text = open(FIXTURE).read()

    # The fixture's Firmware files go; the project's own come back below.
    removed = [i for ids in FIXTURE_FILES.values() for i in ids]
    text = "\n".join(line for line in text.split("\n") if not any(i in line for i in removed))

    # The project's Swift files in Firmware/.
    build_files, file_refs, children, sources = [], [], [], []
    next_id = 0xC0
    for file in firmware_files(project_dir):
        if file in FIXTURE_FILES:
            ref, build = FIXTURE_FILES[file]
        else:
            ref, build = NEW_ID.format(next_id), NEW_ID.format(next_id + 1)
            next_id += 2
        build_files.append(f"\t\t{build} /* {file} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {file} */; }};")
        file_refs.append(f"\t\t{ref} /* {file} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(file)}; sourceTree = \"<group>\"; }};")
        children.append(f"\t\t\t\t{ref} /* {file} */,")
        sources.append(f"\t\t\t\t{build} /* {file} in Sources */,")

    def sorted_section(section, entries):
        # Xcode keeps a section's entries in the order of their identifiers.
        nonlocal text
        start = text.index(f"/* Begin {section} section */\n") + len(f"/* Begin {section} section */\n")
        end = text.index(f"/* End {section} section */")
        lines = [line for line in text[start:end].split("\n") if line] + entries
        text = text[:start] + "\n".join(sorted(lines)) + "\n" + text[end:]

    sorted_section("PBXBuildFile", build_files)
    sorted_section("PBXFileReference", file_refs)
    # In the Firmware group, before Package.swift.
    package = f"\t\t\t\t{PACKAGE_SWIFT} /* Package.swift */,"
    text = text.replace(package, "\n".join(children + [package]))
    # In the Indexing target's Sources phase.
    phase = re.search(r"isa = PBXSourcesBuildPhase;\n\t\t\tfiles = \(\n", text)
    text = text[:phase.end()] + "".join(line + "\n" for line in sources) + text[phase.end():]

    # The template's Indexing settings.
    text = re.sub(r'(configuration for PBXNativeTarget "Indexing" \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n'
                  r'\t\t\tbuildSettings = \{\n).*?(\n\t\t\t\};)',
                  lambda m: m.group(1) + indexing_settings("___PROJECTNAME___") + m.group(2), text, flags=re.S)

    # The fixture's development team is the one of whoever created it.
    text = "\n".join(line for line in text.split("\n") if "DEVELOPMENT_TEAM = " not in line)
    # Xcode only quotes names that need it.
    text = re.sub(r'= "(___PROJECTNAME___(?:Kit)?)";', lambda m: f"= {quoted(m.group(1).replace('___PROJECTNAME___', name))};", text)
    return text.replace("___PROJECTNAME___", name)


def scheme(project_dir, name):
    text = open(os.path.join(TEMPLATE, "scheme.xcscheme")).read().replace("___PROJECTNAME___", name)
    # The Kit package's test targets, in the Test action.
    manifest = open(os.path.join(project_dir, "Packages", f"{name}Kit", "Package.swift")).read()
    tests = re.findall(r'\.testTarget\(\s*name:\s*"([^"]+)"', manifest)
    testable = re.search(r"( *)<TestableReference\b.*?</TestableReference>\n", text, flags=re.S)
    blocks = [testable.group(0).replace('"BlinkTests"', f'"{test}"') for test in tests]
    return text[:testable.start()] + "".join(blocks) + text[testable.end():]


def main(arguments):
    check = "--check" in arguments
    projects = [a for a in arguments if a != "--check"]
    if not projects:
        sys.exit("Usage: python3 tests/xcode_project.py [--check] PROJECT_DIR...")
    differ = []
    for project_dir in projects:
        project_dir = os.path.abspath(project_dir)
        name = os.path.basename(project_dir)
        xcodeproj = os.path.join(project_dir, f"{name}.xcodeproj")
        files = {
            os.path.join(xcodeproj, "project.pbxproj"): pbxproj(project_dir, name),
            os.path.join(xcodeproj, "xcshareddata", "xcschemes", f"{name}.xcscheme"): scheme(project_dir, name),
        }
        for path, content in files.items():
            if check:
                current = open(path).read() if os.path.exists(path) else None
                if current != content:
                    differ.append(os.path.relpath(path))
            else:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w") as f:
                    f.write(content)
        if not check:
            print(f"Wrote {os.path.relpath(xcodeproj)}")
    if differ:
        sys.exit("Out of date (run: python3 tests/xcode_project.py " + " ".join(projects) + "):\n  " + "\n  ".join(differ))


if __name__ == "__main__":
    main(sys.argv[1:])
