# espswift

The command-line tool for Embedded Swift on RISC-V based ESP32 chips, written in Swift. It replaces the scripts and the installer app ESPSwift had, is to be installed with Homebrew, and runs on macOS and Linux; the Xcode template becomes an optional part of it.

It's being built in phases (see below). So far it has:

```
espswift setup [--[no-]xcode-template]     # installs ESP-IDF (with EIM), Swift and the tools they need
espswift new <name> [--board] [--example]   # creates a project from the template and an example, without Xcode (also on Linux)
espswift build [clean] [--verbose]         # builds the project, showing errors as Xcode issues (projects' build.sh runs it)
espswift flash [--port] [--last-build]     # flashes the project's latest build
espswift monitor [--port] [--idf]          # shows the board's serial output, with crashes' backtraces (--idf: ESP-IDF's monitor)
espswift run [--port] [--last-build]       # builds, flashes and monitors (Cmd+R runs it with --last-build)
espswift debug                             # debugs the firmware on the board with LLDB (OpenOCD, built-in USB-JTAG)
espswift add <component> [--header]        # adds an ESP-IDF library (main/idf_component.yml and ESPIDF.h)
espswift settings                          # ESP-IDF's settings menu (menuconfig)
espswift update                            # updates a project created from an older template
espswift doctor                            # checks Python, EIM, ESP-IDF and its tools, Swift, the Xcode template and boards
espswift ports [--first]                   # lists the serial ports of connected boards
espswift xcode install-template            # installs or updates the Xcode template (macOS)
espswift xcode uninstall-template
espswift uninstall [--yes] [--all]         # removes what setup installed (replaces uninstall.sh)
espswift --version
```

`espswift setup` does what `install.sh` used to do (`install.sh` now builds espswift and runs it), and can run again to install what's missing and update the template. On macOS it asks whether to install the Xcode template (without a terminal, it does). It installs missing prerequisites with Homebrew on macOS; on Linux it says which to install, and installs Swift with [swiftly](https://www.swift.org/install/linux/).

The Xcode template it installs comes from, in order: the folder in `ESPSWIFT_RESOURCES`; `share/espswift` next to the `bin` folder espswift is in (where a Homebrew formula puts them); or, when run from this repository, the repository itself.

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
2. `build`, replacing `scripts/build.sh` and the build output filter; projects' `build.sh` calls `espswift build`. *(done)*
3. `flash`, `monitor` and `run`; the Run scheme starts `espswift run` directly, without the monitor wrapper. *(done)*
4. The Python helpers in Swift (the Swift package build, code completion flags), and `add`, `settings` (menuconfig), `update` and `debug`; `scripts/` is gone. *(done)*
5. `new`: creating projects without Xcode, for Linux and other editors; the template test creates its projects with it. *(done)*
6. Removing the SwiftUI installer and `uninstall.sh`, and updating the documentation; the template test runs on Linux too, also in CI. *(done)*

Next: a Homebrew tap and a release workflow, after which `install.sh` can go (see the roadmap).

## How projects use it

`espswift setup` puts espswift at `~/.espswift/bin/espswift`: a link to Homebrew's `bin/espswift` when installed with Homebrew, or to a copy in `~/.espswift/libexec` when built from this repository (`install.sh`). A project's `build.sh`, which Xcode runs on Cmd+B, runs `~/.espswift/bin/espswift build` (or `ESPSWIFT_BIN`, which `tests/test_template.sh` sets to the one it builds).

`espswift build` finds the project from Xcode's settings or the current folder, sets up ESP-IDF's environment (what EIM's activation script sets up, or for an ESP-IDF in `IDF_PATH`, its `export.sh`), sets the chip when `sdkconfig.defaults` names a new one, runs `idf.py` with its output filtered for Xcode (`BuildOutputFilter`), keeps the full output in the build folder (`log/build-output.log`), sets up code completion and records the build for Cmd+R. `--verbose`, or `ESPSWIFT_VERBOSE=1`, shows all of ESP-IDF's output.

Cmd+R (the template's Run scheme) starts `~/.espswift/bin/espswift run --last-build --project "$(PROJECT_DIR)"`: Xcode has just built the project, so it flashes the build `espswift build` recorded for it (in the source folder's `.espswift/last-build`). Xcode fills in `$(PROJECT_DIR)` as the scheme names the project's target for its build settings (`MacroExpansion`); without a project (or one Xcode didn't fill in), `--last-build` flashes the last build of any project (`~/.espswift/last-build`). The monitor reads the serial port in Swift (`Monitor`, with a small C target, `CSerialPort`, for the port settings) and waits for the board when it resets or is unplugged.

The Swift package is built by `espswift internal build-package`, which the project's `main/CMakeLists.txt` runs during ESP-IDF's build (finding espswift through `ESPSWIFT_BIN`, which `espswift build` sets, or `~/.espswift/bin/espswift`). After a build, `espswift build` writes the code completion settings for the Indexing target (`CodeCompletion`).
