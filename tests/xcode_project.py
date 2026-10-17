#!/usr/bin/env python3

# xcode_project.py
# Writes the Xcode project of a project created with `espswift new`, for
# tests/test_template.sh: what Xcode would create from the template, for the
# project's own files.
#
# Only Xcode creates projects from the template, so this starts from a
# project Xcode created (tests/fixtures/project.pbxproj) and applies:
#   - the project's name;
#   - the template's settings for the Indexing target (code completion),
#     with its placeholder toolchain, which `espswift update` fills in;
#   - the Swift files in Firmware/, in the Indexing target (the examples
#     have files of their own);
#   - the template's Run scheme, with the Kit package's test target in its
#     Test action (Cmd+U).
#
# Usage: python3 tests/xcode_project.py PROJECT_DIR [NAME]
#   PROJECT_DIR  The project's folder.
#   NAME         The project's name; by default, the folder's name.

import os
import plistlib
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(REPO_ROOT, "Xcode Template", "ESP32 RISC-V.xctemplate")
FIXTURE = os.path.join(REPO_ROOT, "tests", "fixtures", "project.pbxproj")

# Identifiers for the project's Swift files in Firmware/ (24 hex digits,
# like Xcode's): E5F000000000000000000000 and up.
NEW_ID = "E5F0{:020X}"


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
    """The Swift files in Firmware/ (not its Package.swift), by name."""
    folder = os.path.join(project_dir, "Firmware")
    return sorted(n for n in os.listdir(folder) if n.endswith(".swift") and n != "Package.swift")


def pbxproj(project_dir, name):
    text = open(FIXTURE).read()

    # The fixture's Swift files in Firmware/ (those of the example it was
    # made from) go, wherever they're mentioned; the project's own come back
    # below. Package.swift, in no target, stays.
    group = re.search(r"/\* Firmware \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \((.*?)\);", text, flags=re.S)
    refs = [m.group(1) for m in re.finditer(r"([0-9A-F]{24}) /\* (\S+\.swift) \*/", group.group(1))
            if not m.group(0).endswith("/* Package.swift */")]
    builds = [m.group(1) for ref in refs
              for m in re.finditer(r"([0-9A-F]{24}) /\* \S+ in Sources \*/ = \{isa = PBXBuildFile; fileRef = " + ref, text)]
    removed = refs + builds
    text = "\n".join(line for line in text.split("\n") if not any(i in line for i in removed))

    # The project's Swift files in Firmware/.
    build_files, file_refs, children, sources = [], [], [], []
    for index, file in enumerate(firmware_files(project_dir)):
        ref, build = NEW_ID.format(2 * index), NEW_ID.format(2 * index + 1)
        build_files.append(f"\t\t{build} /* {file} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {file} */; }};")
        file_refs.append(f"\t\t{ref} /* {file} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(file)}; sourceTree = \"<group>\"; }};")
        children.append(f"\t\t\t\t{ref} /* {file} */,")
        sources.append(f"\t\t\t\t{build} /* {file} in Sources */,")

    def add_to_section(section, entries):
        # Xcode keeps a section's entries in the order of their identifiers.
        nonlocal text
        start = text.index(f"/* Begin {section} section */\n") + len(f"/* Begin {section} section */\n")
        end = text.index(f"/* End {section} section */")
        lines = [line for line in text[start:end].split("\n") if line] + entries
        text = text[:start] + "\n".join(sorted(lines)) + "\n" + text[end:]

    add_to_section("PBXBuildFile", build_files)
    add_to_section("PBXFileReference", file_refs)
    # In the Firmware group, before Package.swift.
    package = re.search(r"\t\t\t\t[0-9A-F]{24} /\* Package\.swift \*/,", text).group(0)
    text = text.replace(package, "\n".join(children + [package]))
    # In the Indexing target's Sources phase.
    phase = re.search(r"isa = PBXSourcesBuildPhase;\n\t\t\tfiles = \(\n", text)
    text = text[:phase.end()] + "".join(line + "\n" for line in sources) + text[phase.end():]

    # The template's Indexing settings.
    text = re.sub(r'(configuration for PBXNativeTarget "Indexing" \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n'
                  r'\t\t\tbuildSettings = \{\n).*?(\n\t\t\t\};)',
                  lambda m: m.group(1) + indexing_settings("___PROJECTNAME___") + m.group(2), text, flags=re.S)

    # A development team would be that of whoever made the fixture.
    text = "\n".join(line for line in text.split("\n") if "DEVELOPMENT_TEAM = " not in line)
    # Xcode only quotes names that need it.
    text = re.sub(r'= "(___PROJECTNAME___(?:Kit)?)";', lambda m: f"= {quoted(m.group(1).replace('___PROJECTNAME___', name))};", text)
    return text.replace("___PROJECTNAME___", name)


def scheme(project_dir, name):
    """The template's Run scheme, with the Kit's test target (the template
    names it after the example's module, ___VARIABLE_exampleModule___Tests),
    and espswift's path left as its placeholder."""
    manifest = open(os.path.join(project_dir, "Packages", f"{name}Kit", "Package.swift")).read()
    test = re.search(r'\.testTarget\(\s*name:\s*"([^"]+)"', manifest).group(1)
    text = open(os.path.join(TEMPLATE, "scheme.xcscheme")).read()
    return text.replace("___VARIABLE_exampleModule___Tests", test).replace("___PROJECTNAME___", name)


def main(arguments):
    if len(arguments) not in (1, 2):
        sys.exit("Usage: python3 tests/xcode_project.py PROJECT_DIR [NAME]")
    project_dir = os.path.abspath(arguments[0])
    name = arguments[1] if len(arguments) == 2 else os.path.basename(project_dir)
    xcodeproj = os.path.join(project_dir, f"{name}.xcodeproj")
    files = {
        os.path.join(xcodeproj, "project.pbxproj"): pbxproj(project_dir, name),
        os.path.join(xcodeproj, "xcshareddata", "xcschemes", f"{name}.xcscheme"): scheme(project_dir, name),
    }
    for path, content in files.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(content)


if __name__ == "__main__":
    main(sys.argv[1:])
