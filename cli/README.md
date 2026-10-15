# espswift

The command-line tool for Embedded Swift on RISC-V based ESP32 chips, written in Swift. It's meant to replace `install.sh` and the scripts in `scripts/`, to be installed with Homebrew, and to run on macOS and Linux; the Xcode template becomes an optional part of it.

It's being built in phases (see below). So far it has:

```
espswift setup [--[no-]xcode-template]     # installs ESP-IDF, Swift and the tools they need (replaces install.sh)
espswift doctor                            # checks ESP-IDF, Swift, Python, CMake, Ninja, the Xcode template and boards
espswift ports [--first]                   # lists the serial ports of connected boards
espswift xcode install-template            # installs or updates the Xcode template (macOS)
espswift xcode uninstall-template
espswift uninstall [--yes] [--all]         # removes what setup installed (replaces uninstall.sh)
espswift --version
```

`espswift setup` does what `install.sh` does, and can run again to install what's missing and update the template and scripts. On macOS it asks whether to install the Xcode template (without a terminal, it does). It installs missing prerequisites with Homebrew on macOS; on Linux it says which to install, and installs Swift with [swiftly](https://www.swift.org/install/linux/).

The template and the helper scripts it installs come from, in order: the folder in `ESPSWIFT_RESOURCES`; `share/espswift` next to the `bin` folder espswift is in (where a Homebrew formula puts them); or, when run from this repository, the repository itself.

## Building

```bash
cd cli
swift build
swift test
.build/debug/espswift doctor
```

It builds with Swift 6 on macOS (Xcode's Swift is fine) and on Linux. CI builds and tests it on both (`.github/workflows/cli.yml`).

## Code

- `Sources/espswift`: the command line (swift-argument-parser): parses arguments and prints results.
- `Sources/EspSwiftCore`: what the commands do. It reaches the system (files, the environment, running programs) only through the `System` protocol, so the tests (`Tests/EspSwiftCoreTests`) run the commands against a `FakeSystem`, on any machine.
- `Versions.swift` has the pinned versions of ESP-IDF, Swift and Python (`Pins`). `install.sh` has the same pins until `espswift setup` replaces it.

## Plan

0. Skeleton: `doctor`, `ports`, `--version`, CI on macOS and Linux. *(done)*
1. `setup` and `uninstall`, replacing `install.sh` and `uninstall.sh`, with a prompt for the Xcode template *(done)*; a Homebrew tap and a release workflow *(when it's published)*.
2. `build`, replacing `scripts/build.sh` and the build output filter; projects' `build.sh` calls `espswift build`.
3. `flash`, `monitor` and `run`; the Run scheme starts `espswift run` directly, without the monitor wrapper.
4. The Python helpers in Swift (the Swift package build, code completion flags), and `add`, `settings` (menuconfig), `update` and `debug`.
5. `new`: creating projects without Xcode, for Linux and other editors.
6. Removing `install.sh`, `scripts/` and the SwiftUI installer, and updating the documentation; the template test runs through `espswift`, also on Linux.
