# Embedded Swift Xcode Template for ESP32

Write firmware for RISC-V based ESP32 chips in Swift — build and flash directly from Xcode, just like Arduino IDE, or from Terminal with `espswift`.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Swift](https://img.shields.io/badge/swift-Embedded-orange)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-Experimental%20Preview-yellow)

> ⚠️ **Experimental Preview** — This project is in active development. Commands and installation paths may change without notice. Tested on macOS 27 with Apple Silicon, and on Ubuntu 24.04.

> 🤖 **AI-assisted development** — This project was built with significant help from Claude (Anthropic) as a pair programming tool. Architecture decisions, debugging, and hardware validation were done by the author.

## Features

✅ **Native Swift on Microcontrollers** — Write ESP32 firmware in Swift, not C/C++  
✅ **Choose Your Chip** — ESP32-C2, C3, C5, C6, C61, H2 or P4, picked when you create a project  
✅ **Xcode Integration** — `Cmd+B` builds, `Cmd+R` flashes the board and shows its output, `Cmd+U` runs tests  
✅ **Build Errors in Xcode** — Swift, C and CMake errors in the Issue navigator, linked to their line  
✅ **Code Completion** — completion and jump to definition for Swift and ESP-IDF's C APIs  
✅ **Swift Packages** — use Embedded-ready packages such as swift-mmio; test plain Swift code on your Mac  
✅ **On-Chip Debugging** — breakpoints, backtraces and variables in Swift on the board, with LLDB  
✅ **`espswift` Command-Line Tool** — set up, create, build, flash, monitor and debug, on macOS and Linux  
✅ **NeoPixel Ready** — WS2812 RGB LED example included  

---

## Demo

> 🎬 Demo video coming soon — NeoPixel RGB cycle running on ESP32-C6, built and flashed directly from Xcode.

---

## Quick Start

### Install
```bash
git clone https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template.git
cd Embedded-Swift-Xcode-Template
bash install.sh
```

`install.sh` builds `espswift`, ESPSwift's command-line tool (in `cli/`; building it needs Swift 6, which comes with Xcode), and runs `espswift setup`, which installs ESP-IDF, the Swift toolchain and the tools they need, and asks whether to install the Xcode template. Installation takes 5–10 minutes (~3GB download). Run `~/.espswift/bin/espswift doctor` afterwards to check everything is in order.

On Linux, install ESP-IDF's prerequisites (on Ubuntu: `sudo apt install git wget flex bison gperf python3 python3-pip python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0`) and Swift 6.4 with [swiftly](https://www.swift.org/install/linux/), then run `install.sh`.

### Create a Project in Xcode
1. Restart Xcode
2. File → New → Project → Choose Template… → Other → **ESP32 RISC-V**, and choose your board's chip in the **Chip** pop-up
3. Connect your board via USB
4. Press `Cmd+B` — builds the firmware
5. Press `Cmd+R` — flashes it to the board and shows its serial output in Xcode's console

### Create a Project in Terminal
```bash
~/.espswift/bin/espswift new MyProject --chip esp32c6
cd MyProject
~/.espswift/bin/espswift run        # build, flash and show the serial output
```

---

## Using espswift

Xcode runs `espswift` for you (`Cmd+B`, `Cmd+R`); in Terminal it works in any folder of a project. Add `~/.espswift/bin` to your `PATH` to type just `espswift`.

| Command | What it does |
| --- | --- |
| `espswift new <name> [--chip]` | Creates a project from the template |
| `espswift build [clean]` | Builds the project (`Cmd+B`) |
| `espswift run` | Builds, flashes and shows the serial output (`Cmd+R`) |
| `espswift flash` / `espswift monitor` | Flashes the latest build / shows the serial output (`--idf` for ESP-IDF's monitor, which decodes crashes) |
| `espswift debug` | Debugs the firmware on the board with LLDB |
| `espswift add <library> [--header]` | Adds an ESP-IDF library from the [Component Registry](https://components.espressif.com) |
| `espswift settings` | ESP-IDF's settings menu (menuconfig) |
| `espswift update` | Updates a project created from an older template |
| `espswift ports` | Lists connected boards |
| `espswift doctor` | Checks ESP-IDF, Swift and the other tools |
| `espswift setup` / `espswift uninstall` | Installs, updates or removes ESPSwift |

`espswift help <command>` explains each one; [cli/README.md](cli/README.md) explains how it works.

---

## Serial Monitor

`Cmd+R` streams live serial output from the board directly into Xcode's debug console — no external tools needed.

```
=================================================
 ESP32 Serial Monitor
 Port: /dev/cu.usbmodem... @ 115200 baud
=================================================
Hello from Embedded Swift on ESP32!
LED: Red
LED: Green
LED: Blue
```

> **Note:** Xcode's console is output-only. For interactive serial input, use `espswift monitor --idf` in Terminal.

---

## Adding Libraries

To add an ESP-IDF component library, run this in Terminal in your project's folder. In Xcode's Project navigator, Control-click a folder of the project and choose **Open Terminal at Location** to get there:

```bash
~/.espswift/bin/espswift add espressif/button --header iot_button.h
```

This updates `main/idf_component.yml` and `Firmware/ESPIDF/include/ESPIDF.h`, the C header Swift code imports with `import ESPIDF`. Press `Cmd+B` to download and build the library.

A project's Swift code is in Swift packages too: the firmware can use Swift packages that support Embedded Swift, such as [swift-mmio](https://github.com/apple/swift-mmio), and code that doesn't use ESP-IDF goes in a package of the project that Xcode tests on the Mac (`Cmd+U`). The project's README explains both, and other common tasks, such as changing ESP-IDF settings.

---

## Swift Firmware Example

```swift
import ESPIDF

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

This is expected. Xcode runs `espswift` on your Mac, which builds and flashes firmware to the connected ESP32 board over USB. The destination refers to where `espswift` runs, not where the firmware is deployed.

- **Xcode Destination**: My Mac (`espswift` runs here)
- **Actual Flash Target**: your ESP32 board (connected via USB)

### Can I debug the firmware on the board?

Yes, with LLDB in Terminal: `espswift debug` connects to the chip's built-in USB-JTAG (through the board's native USB port) with OpenOCD, and gives you breakpoints in Swift, backtraces and variables. The README in each new project explains it. Xcode's own debugger can't be used: Xcode only debugs Mac programs and Apple devices.

### Which chips are supported?

The RISC-V based ESP32 chips: ESP32-C2, C3, C5, C6, C61, H2 and P4. Choose one in the **Chip** pop-up when you create a project. The template is tested on hardware with the ESP32-C6; the other chips are tested by building only.

The Xtensa based chips (the original ESP32, ESP32-S2 and ESP32-S3, found for example on ESP32 DevKitV1 boards) are not supported: Swift doesn't support Xtensa.

To switch an existing project to another chip, change `CONFIG_IDF_TARGET` in `sdkconfig.defaults` and build again. The example's LED pin is set per chip in `Firmware/ESPIDF/include/ESPIDF.h`, for Espressif's DevKit boards.

### Why is there an Indexing target?

Xcode doesn't index the project's main target, because ESP-IDF builds it. The second target, **Indexing**, exists only so Xcode can offer code completion and jump to definition. Every build gives it ESP-IDF's current compiler settings (see `cli/Sources/EspSwiftCore/CodeCompletion.swift`), so completion works after the first `Cmd+B`. You never need to build it.

Because Xcode's own toolchain can't compile Embedded Swift, the Indexing target uses the Swift toolchain `espswift setup` installed, which it writes into the template. Projects keep the toolchain they were created with; after a newer Swift version is installed, the build warns about it, and `espswift update` (see [Updating ESPSwift](#updating-espswift)) points existing projects at the new toolchain.

### Why does the first build take so long?

The first build downloads ESP-IDF component dependencies and builds all of ESP-IDF (~minutes). Subsequent builds are incremental and much faster.

### Where is the build output?

Like any Xcode project, the build output lives in DerivedData, not in your project folder: `~/Library/Developer/Xcode/DerivedData/<Project>-<hash>/Build/Intermediates.noindex/<Project>.build/Debug/<Project>.build/esp-idf/`. **Product ▸ Show Build Folder in Finder** takes you to the `Build` folder above it, and **Product ▸ Clean Build Folder** removes it.

`espswift build` in Terminal builds into the `build/` folder in the project's source folder instead, which is a separate build. `espswift flash` flashes whichever of the project's builds is the latest.

### My board isn't detected

Run `espswift ports` with the board connected. Supported USB interfaces:
- Native USB-CDC → `/dev/cu.usbmodem*` (Linux: `/dev/ttyACM*`)
- WCH CH340 → `/dev/cu.wchusbserial*` (Linux: `/dev/ttyUSB*`)
- CP210x (macOS built-in driver), FTDI → `/dev/cu.usbserial*` (Linux: `/dev/ttyUSB*`)
- CP210x (legacy Silicon Labs driver) → `/dev/cu.SLAB_USBtoUART*`

CH340-based boards may need a driver on macOS: [WCH CH340 Driver](https://www.wch-ic.com/downloads/CH341SER_MAC_ZIP.html). On Linux, add yourself to the `dialout` group to use serial ports.

---

## Architecture

```
Embedded-Swift-Xcode-Template/
├── install.sh                        # Builds espswift and runs espswift setup
├── cli/                              # espswift, ESPSwift's command-line tool (see cli/README.md)
│   ├── Sources/espswift/            # The commands (swift-argument-parser)
│   ├── Sources/EspSwiftCore/        # What they do: setup, build, flash, monitor, debug, ...
│   └── Tests/EspSwiftCoreTests/     # Unit tests (swift test)
├── tests/
│   └── test_template.sh             # Builds the template for every chip (also run in CI, on macOS and Linux)
└── Xcode Template/
    └── ESP32 RISC-V.xctemplate/
        ├── TemplateInfo.plist       # Xcode template configuration
        ├── README.md                # Getting-started guide for the new project
        ├── build.sh                 # Runs espswift build
        ├── CMakeLists.txt           # Root CMake configuration
        ├── sdkconfig.defaults       # ESP-IDF defaults (watchdog off)
        ├── gitignore                # Installed as .gitignore at the project root
        ├── scheme.xcscheme          # Run scheme (Cmd+R: espswift run --last-build)
        ├── main/
        │   ├── CMakeLists.txt       # Builds the Swift package (espswift) and links it
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

- macOS: Xcode 26 or later (tested with Xcode 26.6 and 27), and a macOS version that runs it. Code completion needs Xcode 27.
- Linux: Ubuntu 24.04 or similar, with ESP-IDF's prerequisites and Swift 6.4 (see [Install](#install))
- Python, CMake and Ninja: on macOS, `espswift setup` installs any that are missing with [Homebrew](https://brew.sh) (Python 3.14); on Linux, Python 3.10 or newer
- About 10 GB of disk space: the Swift toolchain takes about 5 GB, ESP-IDF and its tools about 4 GB, and each project's build output about 250 MB
- An internet connection for installing, and for each project's first build (which downloads its ESP-IDF components)
- A board with a RISC-V based ESP32 chip (ESP32-C2, C3, C5, C6, C61, H2 or P4) and a USB connection

---

## What Gets Installed

`espswift setup` installs the following into your home directory:

| Path | Contents |
|------|----------|
| `~/.espswift/bin/espswift` | `espswift`, which projects build with (a copy in `~/.espswift/libexec`) |
| `~/.espswift/esp-idf/` | ESP-IDF 6.1 (~750 MB) |
| `~/.espswift/python/` | Link to the Python ESP-IDF's Python environment was made for (3.14 on macOS) |
| `~/.espressif/` | ESP-IDF's compilers, tools and Python environment (~3.5 GB, including ~1 GB of downloaded archives) |
| `~/Library/Developer/Toolchains/` | macOS: the Swift 6.4.0 release toolchain (~5 GB), installed with [swiftly](https://www.swift.org/install/macos/) if you have it, otherwise from swift.org's installer. On Linux, swiftly's toolchain, or the Swift on your `PATH` |
| `~/.espswift/swift-toolchain` | Path of the Swift toolchain that projects use |
| `~/Library/Developer/Xcode/Templates/` | ESP32 RISC-V Xcode template (macOS) |

Nothing is installed to system directories. Everything is scoped to your user home directory.

### Updating ESPSwift

Run `install.sh` again from an up-to-date copy of this repository. Each project's `build.sh` only runs the `espswift` that `install.sh` installs (`~/.espswift/bin/espswift build`), so updating ESPSwift also updates how existing projects build.

When an update changes what projects need, the build shows a warning in Xcode's Issue navigator with the command that updates the project. You can also run it yourself, in the project's folder:

```bash
~/.espswift/bin/espswift update
```

It replaces the project's `build.sh` with the template's and points code completion at the Swift version `espswift setup` installed; it only changes what needs changing.

### Switching ESP-IDF versions

`espswift setup` installs a fixed ESP-IDF release (`Pins.espIDF` in `cli/Sources/EspSwiftCore/Versions.swift`) and never replaces an existing `~/.espswift/esp-idf`; `espswift doctor` says when it's another version. To switch to the pinned release:

```bash
rm -rf ~/.espswift/esp-idf
bash install.sh
```

Then, in each existing project, press `Cmd+Shift+K` followed by `Cmd+B` in Xcode. ESP-IDF updates the project's `sdkconfig` for the new version; review that change before committing it.

---

## Uninstall

To remove ESPSwift, run:

```bash
~/.espswift/bin/espswift uninstall
```

It removes `~/.espswift` (ESP-IDF and espswift itself) and the Xcode template. It then asks before removing things other projects may also use: the Swift toolchain (through swiftly, if you use it), ESP-IDF's tools in `~/.espressif`, and ESP-IDF's component download cache. Use `--all` to remove those without asking, and `--yes` to skip the confirmation.

It never removes Homebrew or the packages installed with it (Python, CMake, Ninja), swiftly, or your projects.

---

## Roadmap

This project is being developed as part of the [Swift Mentorship Program](https://www.swift.org/mentorship/). See [ROADMAP.md](ROADMAP.md) for what's planned next.

---

## Known Issues & Limitations

- Embedded Swift is experimental; not all Swift standard library features are available
- Xcode's serial console is read-only (no interactive input); use `espswift monitor --idf` in Terminal
- The firmware package is built with SwiftPM's deprecated `--build-system native` (see [ROADMAP.md](ROADMAP.md))
- The very first lines a board prints after flashing can be missing in the serial output; press the board's RESET button to see them

See all open issues: [GitHub Issues](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues)

---

## License

MIT — see [LICENSE](LICENSE)

## References

- [Embedded Swift Documentation](https://www.swift.org/embedded/)
- [ESP-IDF Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c6/)
- [ESP-IDF Component Registry](https://components.espressif.com)
- [ESP32-C6 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c6_datasheet_en.pdf)
