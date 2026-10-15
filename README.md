# Embedded Swift Xcode Template for ESP32-C6

Write ESP32-C6 firmware in Swift — build and flash directly from Xcode, just like Arduino IDE.

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/swift-Embedded-orange)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-Experimental%20Preview-yellow)

> ⚠️ **Experimental Preview** — This project is in active development. APIs, scripts, and installation paths may change without notice. Tested on macOS 26 with Apple Silicon.

> 🤖 **AI-assisted development** — This project was built with significant help from Claude (Anthropic) as a pair programming tool. Architecture decisions, debugging, and hardware validation were done by the author.

## Features

✅ **Native Swift on Microcontrollers** — Write ESP32 firmware in Swift, not C/C++  
✅ **Choose Your Chip** — ESP32-C2, C3, C5, C6, C61, H2 or P4, picked when you create a project  
✅ **Xcode Integration** — `Cmd+B` builds, `Cmd+R` flashes the board and shows its output  
✅ **Serial Monitor** — `Cmd+R` streams board output to Xcode console  
✅ **Code Completion** — completion and jump to definition for Swift and ESP-IDF's C APIs  
✅ **One-Click Install** — Single `install.sh` sets up everything  
✅ **On-Chip Debugging** — breakpoints, backtraces and variables in Swift on the board, with LLDB  
✅ **NeoPixel Ready** — WS2812 RGB LED example included  

---

## Demo

> 🎬 Demo video coming soon — NeoPixel RGB cycle running on ESP32-C6, built and flashed directly from Xcode.

---

## Quick Start

### Option 1: Installer App (Recommended)
Download and run `ESPSwiftInstaller.app` from [Releases](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/releases).

### Option 2: Terminal
```bash
git clone https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template.git
cd Embedded-Swift-Xcode-Template
bash install.sh
```

`install.sh` builds `espswift`, ESPSwift's command-line tool (in `cli/`, which needs Swift 6, part of Xcode), and runs `espswift setup`, which installs everything else. Installation takes 5–10 minutes (~3GB download).

### Create a Project
1. Restart Xcode
2. File → New → Project → Other → **ESP32 RISC-V**, and choose your board's chip in the **Chip** pop-up
3. Connect your board via USB
4. Press `Cmd+B` — builds the firmware
5. Press `Cmd+R` — flashes it to the board and shows its serial output in Xcode's console

---

## Serial Monitor

After the first build, pressing `Cmd+R` streams live serial output from the board directly into Xcode's debug console — no external tools needed.

```
=================================================
ESP32 Serial Monitor
Port: /dev/cu.usbmodem... @ 115200 baud
Hello from Embedded Swift on ESP32!
LED: Red
LED: Green
LED: Blue
```

> **Note:** Xcode's console is output-only. For interactive serial input, use an external tool like `screen /dev/cu.usbmodem... 115200`.

---

## Adding Libraries

To add an ESP-IDF component library, run this in Terminal from your project's source folder, the one containing `build.sh` and `main/`. In Xcode's Project navigator, Control-click that folder (it has your project's name) and choose **Open Terminal at Location** to get there:

```bash
~/.espswift/scripts/add_library.sh espressif/button iot_button.h
```

This automatically updates `main/idf_component.yml` and `Firmware/ESPIDF/include/ESPIDF.h`, the C header Swift code imports with `import ESPIDF`. Press `Cmd+B` to download and build the library.

A project's Swift code is in Swift packages too: the firmware can use Swift packages that support Embedded Swift, such as [swift-mmio](https://github.com/apple/swift-mmio), and code that doesn't use ESP-IDF goes in a package of the project that Xcode tests on the Mac (`Cmd+U`). The project's README explains both.

Every new project also includes a `README.md` that walks through this and other common tasks, such as changing ESP-IDF settings with `idf.py menuconfig`.

Available libraries: [ESP-IDF Component Registry](https://components.espressif.com)

---

## Swift Firmware Example

```swift
@_cdecl("app_main")
public func app_main() {
    print("Hello from Embedded Swift on ESP32!")

    while true {
        vTaskDelay(pd_ms_to_ticks(1000))
        print("Tick...")
    }
}
```

---

## FAQ

### Why is the Xcode destination set to "My Mac"?

This is expected. Xcode runs a macOS helper tool on your Mac, which builds and flashes firmware to the connected ESP32 board over USB. The destination refers to where the helper runs, not where the firmware is deployed.

- **Xcode Destination**: My Mac (the helper runs here)
- **Actual Flash Target**: your ESP32 board (connected via USB)

### Can I debug the firmware on the board?

Yes, with LLDB in Terminal: `~/.espswift/scripts/debug.sh` connects to the chip's built-in USB-JTAG (through the board's native USB port) with OpenOCD, and gives you breakpoints in Swift, backtraces and variables. The README in each new project explains it. Xcode's own debugger can't be used: Xcode only debugs Mac programs and Apple devices.

### Which chips are supported?

The RISC-V based ESP32 chips: ESP32-C2, C3, C5, C6, C61, H2 and P4. Choose one in the **Chip** pop-up when you create a project. The template is tested on hardware with the ESP32-C6; the other chips are tested by building only.

The Xtensa based chips (the original ESP32, ESP32-S2 and ESP32-S3, found for example on ESP32 DevKitV1 boards) are not supported: Swift doesn't support Xtensa.

To switch an existing project to another chip, change `CONFIG_IDF_TARGET` in `sdkconfig.defaults` and build again. The example's LED pin is set per chip in `Firmware/ESPIDF/include/ESPIDF.h`, for Espressif's DevKit boards.

### Why is there an Indexing target?

Xcode doesn't index the project's main target, because ESP-IDF builds it. The second target, **Indexing**, exists only so Xcode can offer code completion and jump to definition. Every build gives it ESP-IDF's current compiler settings (see `scripts/setup_indexing.sh`), so completion works after the first `Cmd+B`. You never need to build it.

Because Xcode's own toolchain can't compile Embedded Swift, the Indexing target uses the Swift toolchain `install.sh` installed, which `install.sh` writes into the template. Projects keep the toolchain they were created with; after `install.sh` installs a newer Swift version, the build warns about it, and `update_project.sh` (see [Updating ESPSwift](#updating-espswift)) points existing projects at the new toolchain.

### Why does the first build take so long?

The first build downloads ESP-IDF component dependencies (~minutes). Subsequent builds are incremental and much faster (~35 seconds).

### Where is the build output?

Like any Xcode project, the build output lives in DerivedData, not in your project folder: `~/Library/Developer/Xcode/DerivedData/<Project>-<hash>/Build/Intermediates.noindex/<Project>.build/Debug/<Project>.build/esp-idf/`. **Product ▸ Show Build Folder in Finder** takes you to the `Build` folder above it, and **Product ▸ Clean Build Folder** removes it.

Running `idf.py` yourself from Terminal uses ESP-IDF's default `build/` folder in the project directory instead, which is a separate build. Pass `-B <path>` to reuse the Xcode one.

### My board isn't detected

Run `ls /dev/cu.*` with the board connected. Supported USB interfaces:
- Native USB-CDC → `/dev/cu.usbmodem*`
- WCH CH340 → `/dev/cu.wchusbserial*`
- CP210x (macOS built-in driver), FTDI → `/dev/cu.usbserial*`
- CP210x (legacy Silicon Labs driver) → `/dev/cu.SLAB_USBtoUART*`

CH340-based boards may need a driver: [WCH CH340 Driver](https://www.wch-ic.com/downloads/CH341SER_MAC_ZIP.html)

### `Cmd+R` doesn't show serial output

New projects come with the Run scheme that flashes the board and shows its output. In projects created before that, the scheme is generated on the first build, and Xcode only picks it up after you close and reopen the project ([#3](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues/3)).

---

## Architecture

```
Embedded-Swift-Xcode-Template/
├── install.sh                        # Builds espswift and runs espswift setup
├── uninstall.sh                      # Removes what install.sh installed
├── cli/                              # espswift, ESPSwift's command-line tool (see cli/README.md)
├── tests/
│   └── test_template.sh             # Builds the template for every chip (also run in CI)
├── scripts/
│   ├── build_package.py             # Builds a project's Swift package with SwiftPM
│   ├── run.sh                       # Cmd+R: flashes the last build, then starts the monitor
│   ├── debug.sh                     # Debugs the firmware on the board with LLDB
│   ├── detect_port.sh               # Auto-detects the connected board
│   ├── flash.sh                     # Flashes firmware via idf.py
│   ├── monitor.sh                   # Streams serial output to stdout
│   ├── setup_scheme.sh              # Auto-configures Xcode Run scheme
│   ├── setup_indexing.sh            # Compiler settings for code completion
│   ├── indexing_flags.py            # (with SwiftPM's flags for the package)
│   ├── update_project.sh            # Updates projects created from an older template
│   └── add_library.sh               # Adds ESP-IDF component libraries
├── installer/
│   ├── build_pkg.sh                 # Builds .pkg installer
│   └── ESPSwiftInstaller/           # SwiftUI installer app
└── Xcode Template/
└── ESP32 RISC-V.xctemplate/
├── TemplateInfo.plist       # Xcode template configuration
├── README.md                # Getting-started guide for the new project
├── build.sh                 # Runs espswift build
├── CMakeLists.txt           # Root CMake configuration
├── sdkconfig.defaults       # ESP-IDF defaults (watchdog off)
├── gitignore                # Installed as .gitignore at the project root
├── scheme.xcscheme          # Run scheme (Cmd+R: flash and show serial output)
├── main/
│   ├── CMakeLists.txt       # Builds the Swift package (build_package.py) and links it
│   ├── idf_component.yml    # ESP-IDF dependencies
│   └── swift_flags.c        # Empty; provides ESP-IDF's C flags to the Swift package build
├── Firmware/                # Next to the .xcodeproj in new projects
│   ├── Firmware.swift       # Firmware entry point (app_main)
│   ├── Package.swift        # The firmware package, built by ESP-IDF with SwiftPM
│   └── ESPIDF/include/ESPIDF.h   # ESP-IDF's C APIs for Swift (import ESPIDF)
└── Kit/                     # Packages/<Project>Kit: plain Swift, tested on the Mac (Cmd+U)
    ├── Package.swift
    ├── Sources/Blink/
    └── Tests/BlinkTests/
```

---

## System Requirements

- Xcode 26 or later (tested with Xcode 26.6 and 27), and a macOS version that runs it. Code completion needs Xcode 27.
- Python 3.14, CMake and Ninja; `install.sh` installs any that are missing with [Homebrew](https://brew.sh)
- About 10 GB of disk space: the Swift toolchain takes about 5 GB, ESP-IDF and its tools about 4 GB, and each project's build output about 250 MB
- An internet connection for installing, and for each project's first build (which downloads its ESP-IDF components)
- A board with a RISC-V based ESP32 chip (ESP32-C2, C3, C5, C6, C61, H2 or P4) and a USB connection

---

## What Gets Installed

Running `install.sh` or `ESPSwiftInstaller.app` installs the following into your home directory:

| Path | Contents |
|------|----------|
| `~/.espswift/bin/espswift` | `espswift`, which projects build with |
| `~/.espswift/esp-idf/` | ESP-IDF 6.1 (~750 MB) |
| `~/.espswift/scripts/` | Helper scripts (flash, monitor, code completion, etc.) |
| `~/.espswift/python/` | Link to Python 3.14, the version ESP-IDF's Python environment was made for |
| `~/.espressif/` | ESP-IDF's compilers, tools and Python environment (~3.5 GB, including ~1 GB of downloaded archives) |
| `~/Library/Developer/Toolchains/` | Swift 6.4.0 release toolchain (~5 GB), installed with [swiftly](https://www.swift.org/install/macos/) if you have it, otherwise from swift.org's installer |
| `~/.espswift/swift-toolchain` | Path of the Swift toolchain that projects use |
| `~/Library/Developer/Xcode/Templates/` | ESP32 RISC-V Xcode template |

Nothing is installed to system directories. Everything is scoped to your user home directory.

### Updating ESPSwift

Run `install.sh` again from an up-to-date copy of this repository. Each project's `build.sh` only runs the `espswift` that `install.sh` installs (`~/.espswift/bin/espswift build`), so updating ESPSwift also updates how existing projects build.

When an update changes what projects need, the build shows a warning in Xcode's Issue navigator with the command that updates the project. You can also run it yourself, with the folder that contains the project's `.xcodeproj`:

```bash
~/.espswift/scripts/update_project.sh ~/Developer/MyProject
```

It replaces the project's `build.sh` with the template's, points code completion at the Swift version `install.sh` installed, and adds the Run scheme if it's missing; it only changes what needs changing. Projects created before the build warned about this (with the whole build script in their own `build.sh`) need it once too.

### Switching ESP-IDF versions

`install.sh` installs a fixed ESP-IDF release (the `IDF_VERSION` setting at the top of the script) and never replaces an existing `~/.espswift/esp-idf`. Installs made before the version was pinned cloned ESP-IDF's development `master` branch; re-running `install.sh` warns about this. To switch to the pinned release:

```bash
rm -rf ~/.espswift/esp-idf
bash install.sh
```

Then, in each existing project, press `Cmd+Shift+K` followed by `Cmd+B` in Xcode. ESP-IDF updates the project's `sdkconfig` for the new version; review that change before committing it.

---

## Uninstall

To remove ESPSwift, run from the repository folder:

```bash
bash uninstall.sh
```

It removes `~/.espswift` (ESP-IDF, the helper scripts) and the Xcode template. It then asks before removing things other projects may also use: the Swift toolchain (through swiftly, if you use it), ESP-IDF's tools in `~/.espressif`, and ESP-IDF's component download cache. Use `--all` to remove those without asking, and `--yes` to skip the confirmation.

It never removes Homebrew or the packages installed with it (Python, CMake, Ninja), swiftly, or your projects.

> **Note:** Earlier versions of `install.sh` installed swiftly in `~/.swiftly/` and a development snapshot toolchain (`swift-DEVELOPMENT-SNAPSHOT-*.xctoolchain`). `uninstall.sh` leaves those alone; remove them only if you don't use them for anything else.

---

## Roadmap

This project is being developed as part of the [Swift Mentorship Program](https://www.swift.org/mentorship/). See [ROADMAP.md](ROADMAP.md) for what's planned next.

---

## Known Issues & Limitations

- Embedded Swift is experimental; not all Swift standard library features are available
- Xcode's serial console is read-only (no interactive input)
- Build times are longer than native C/C++ due to full Swift recompilation

See all open issues: [GitHub Issues](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues)

---

## License

MIT — see [LICENSE](LICENSE)

## References

- [Embedded Swift Documentation](https://www.swift.org/embedded/)
- [ESP-IDF Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c6/)
- [ESP-IDF Component Registry](https://components.espressif.com)
- [ESP32-C6 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c6_datasheet_en.pdf)
