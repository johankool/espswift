# ESPSwift: Embedded Swift for ESP32 (incl. Xcode Template)

Write firmware for RISC-V based ESP32 chips in Swift — build and flash directly from Xcode, just like Arduino IDE, or from Terminal with `espswift`.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Swift](https://img.shields.io/badge/swift-Embedded-orange)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-Experimental%20Preview-yellow)

> ⚠️ **Experimental Preview** — This project is in active development. Commands and installation paths may change without notice. Tested on macOS 27 with Apple Silicon, and on Ubuntu 24.04.

ESPSwift started as a fork of [Embedded Swift Xcode Template](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template) by Gibeom Ko. His project was developed as part of the [Swift Mentorship Program](https://www.swift.org/mentorship/). 

> 🤖 **AI-assisted development** — This project was built with significant help from Claude (Anthropic) as a pair programming tool. Architecture decisions, debugging, and hardware validation were done by the authors.

## Features

✅ **Native Swift on Microcontrollers** — Write ESP32 firmware in Swift, not C/C++  
✅ **Choose Your Board** — a DevKit or another board with an ESP32-C2, C3, C5, C6, C61, H2 or P4, picked when you create a project; it sets the chip, LED and flash size  
✅ **Xcode Integration** — `Cmd+B` builds, `Cmd+R` flashes the board and shows its output, `Cmd+U` runs tests  
✅ **Build Errors in Xcode** — Swift, C and CMake errors in the Issue navigator, linked to their line  
✅ **Code Completion** — completion and jump to definition for Swift and ESP-IDF's C APIs  
✅ **Swift Packages** — use Embedded-ready packages such as swift-mmio; test plain Swift code on your Mac  
✅ **On-Chip Debugging** — breakpoints, backtraces and variables in Swift on the board, with LLDB  
✅ **Crash Backtraces** — a crash's backtrace, with Swift function names, files and lines, in Xcode's console  
✅ **`espswift` Command-Line Tool** — set up, create, build, flash, monitor and debug, on macOS and Linux  
✅ **Examples to Start From** — Blink (whether your board's LED is a WS2812 RGB LED, separate red, green and blue LEDs or a one-colour LED), a button, an I2C sensor or display, Wi-Fi with HTTPS, a Bluetooth LE light or deep sleep, chosen when you create a project  
✅ **Tutorial** — [Your First Firmware](#tutorial), from setting up to testing your change on the Mac  

---

## Quick Start

### Install
With [Homebrew](https://brew.sh):

```bash
brew tap johankool/espswift
brew trust --tap johankool/espswift
brew trust --formula espressif/eim/eim
brew install espswift
espswift setup
```

Homebrew asks you to trust taps other than its own: ESPSwift's, and Espressif's, whose EIM installs ESP-IDF. Homebrew builds `espswift` from the release's source, which needs Xcode; `brew install --HEAD espswift` builds the main branch instead.

Or from a copy of this repository:

```bash
git clone https://github.com/johankool/espswift.git
cd espswift
bash install.sh
```

`install.sh` builds `espswift`, ESPSwift's command-line tool (in `cli/`; building it needs Swift 6, which comes with Xcode), and runs `espswift setup`, which installs ESP-IDF, the Swift toolchain and the tools they need, and asks whether to install the Xcode template. Installation takes 5–10 minutes (~3GB download). Run `~/.espswift/bin/espswift doctor` afterwards to check everything is in order.

ESP-IDF is installed with [EIM](https://docs.espressif.com/projects/idf-im-ui/en/latest/), Espressif's ESP-IDF Installation Manager, so it's shared with Espressif's other tools, such as its VS Code extension. On macOS, `install.sh` installs EIM with Homebrew, from Espressif's tap, which it trusts for this (`brew trust --formula espressif/eim/eim`), as Homebrew requires.

On Linux, install ESP-IDF's prerequisites (on Ubuntu: `sudo apt install git wget flex bison gperf python3 python3-pip python3-venv cmake ccache libffi-dev libssl-dev dfu-util libusb-1.0-0`), [EIM](https://docs.espressif.com/projects/idf-im-ui/en/latest/) (from Espressif's package repository, or with Homebrew) and Swift 6.4 with [swiftly](https://www.swift.org/install/linux/), then run `install.sh`.

### Create a Project in Xcode
1. Restart Xcode
2. File → New → Project → Choose Template… → Other → **ESP32 RISC-V**, choose your board in the **Board** pop-up (or Other, with its chip), and what to start from in the **Example** pop-up (see [Examples](#examples))
3. Connect your board via USB
4. Press `Cmd+B` — builds the firmware
5. Press `Cmd+R` — flashes it to the board and shows its serial output in Xcode's console

### Create a Project in Terminal
```bash
~/.espswift/bin/espswift new MyProject   # asks for your board and an example
cd MyProject
~/.espswift/bin/espswift run        # build, flash and show the serial output
```

---

## Using espswift

Xcode runs `espswift` for you (`Cmd+B`, `Cmd+R`); in Terminal it works in any folder of a project. Add `~/.espswift/bin` to your `PATH` to type just `espswift`.

| Command | What it does |
| --- | --- |
| `espswift new <name> [--board] [--example]` | Creates a project from the template; without `--board` and `--example`, asks for them |
| `espswift build [clean]` | Builds the project (`Cmd+B`) |
| `espswift run` | Builds, flashes and shows the serial output (`Cmd+R`) |
| `espswift flash` / `espswift monitor` | Flashes the latest build / shows the serial output, with crashes' backtraces (`--idf` for ESP-IDF's monitor, which takes input) |
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
        vTaskDelay(ticks(milliseconds: 1000))  // ticks(milliseconds:) is in FreeRTOS.swift
        print("Tick...")
    }
}
```

---

## Tutorial

New to Embedded Swift or the ESP32? **Your First Firmware**, a DocC tutorial in `Documentation/ESPSwift.docc`, takes you from setting up ESPSwift to running a project on your board, changing it, and testing it on your Mac. To read it, open the repository's folder in Terminal and run:

```bash
xcrun docc preview Documentation/ESPSwift.docc
```

and open the address it prints (`/tutorials/espswift`).

---

## Examples

A new project starts from one of the template's examples: the **Example** pop-up in Xcode, or `espswift new --example` (see `--list-examples`). Each works on every board in the Board pop-up; the pins it uses are those of your board. The comments at the top of the project's `Firmware/Firmware.swift` explain it, and what to wire.

| Example | What it does | What it shows |
| --- | --- | --- |
| Blink (`blink`) | Blinks the LED: red, green, blue, off | The board's LED, whatever kind it is |
| Button input (`button-input`) | The BOOT button changes the LED's colour; holding it turns the LED off | Reading a GPIO pin, with debouncing tested on the Mac |
| I2C sensor (`i2c-sensor`) | Reads a Sensirion SHT4x temperature and humidity sensor, and shows the temperature on the LED | ESP-IDF's I2C driver; checksums and conversions tested on the Mac |
| I2C display (`i2c-display`) | Shows text on an SSD1306 OLED display (128 × 64, such as Adafruit's): a title, the board, how long it's been running and a bar | An I2C display driver in Swift; drawing and a 5 × 7 font tested on the Mac |
| Wi-Fi and HTTPS (`wifi-request`) | Connects to your Wi-Fi network and requests a web page over HTTPS; until you set your network in `Credentials.swift`, lists the networks nearby | ESP-IDF's Wi-Fi, events and HTTP client, with its certificate bundle |
| Bluetooth LE light (`ble-light`) | A phone (with an app such as nRF Connect or LightBlue) connects and writes the LED's colour: three bytes, such as `200000` for red | A GATT server with NimBLE, and C callbacks in Swift |
| Deep sleep (`deep-sleep`) | Shows a colour, sleeps for 10 seconds, wakes up with the next one | Deep sleep, a timer wake-up, and a variable in RTC memory (`@section(".rtc.data")`) |

The ESP32-H2 and ESP32-P4 have no Wi-Fi, and the ESP32-P4 has no Bluetooth; there, those examples say so. A board in deep sleep isn't connected over USB: to flash it, hold BOOT while pressing RESET.

---

## FAQ

### Why is the Xcode destination set to "My Mac"?

This is expected. Xcode runs `espswift` on your Mac, which builds and flashes firmware to the connected ESP32 board over USB. The destination refers to where `espswift` runs, not where the firmware is deployed.

- **Xcode Destination**: My Mac (`espswift` runs here)
- **Actual Flash Target**: your ESP32 board (connected via USB)

### Can I debug the firmware on the board?

Yes, with LLDB in Terminal: `espswift debug` connects to the chip's built-in USB-JTAG (through the board's native USB port) with OpenOCD, and gives you breakpoints in Swift, backtraces and variables. The README in each new project explains it. Xcode's own debugger can't be used: Xcode only debugs Mac programs and Apple devices.

### Which chips are supported?

The RISC-V based ESP32 chips: ESP32-C2, C3, C5, C6, C61, H2 and P4. Choose your board in the **Board** pop-up when you create a project: it lists Espressif's DevKits and a few others (Seeed Studio XIAO ESP32C6, M5Stack NanoC6), and Other for each chip. The template is tested on hardware with the ESP32-C6; the other chips are tested by building only.

The Xtensa based chips (the original ESP32, ESP32-S2 and ESP32-S3, found for example on ESP32 DevKitV1 boards) are not supported: Swift doesn't support Xtensa.

To switch an existing project to another chip, change `CONFIG_IDF_TARGET` in `sdkconfig.defaults` and build again. The example's LED is set in `Firmware/Board.swift`, for the board chosen when the project was created.

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
espswift/
├── install.sh                        # Builds espswift and runs espswift setup
├── cli/                              # espswift, ESPSwift's command-line tool (see cli/README.md)
│   ├── Sources/espswift/            # The commands (swift-argument-parser)
│   ├── Sources/EspSwiftCore/        # What they do: setup, build, flash, monitor, debug, ...
│   └── Tests/EspSwiftCoreTests/     # Unit tests (swift test)
├── Documentation/ESPSwift.docc/      # The DocC tutorial, Your First Firmware
├── tests/
│   ├── test_template.sh             # Builds the template for every chip, and its examples (also run in CI, on macOS and Linux)
│   ├── xcode_project.py             # Writes a test project's Xcode project, as Xcode would
│   └── check_tutorial.sh            # Builds the tutorial and checks it against the template
└── Xcode Template/
    └── ESP32 RISC-V.xctemplate/
        ├── TemplateInfo.plist       # Xcode template configuration
        ├── README.md                # Getting-started guide for the new project
        ├── build.sh                 # Runs espswift build
        ├── CMakeLists.txt           # Root CMake configuration
        ├── sdkconfig.defaults       # ESP-IDF defaults (watchdog off)
        ├── gitignore                # Installed as .gitignore at the project root
        ├── scheme.xcscheme          # Run scheme (Cmd+R: espswift run --last-build --project ...)
        ├── main/
        │   ├── CMakeLists.txt       # Builds the Swift package (espswift) and links it
        │   ├── idf_component.yml    # ESP-IDF dependencies
        │   └── swift_flags.c        # Empty; provides ESP-IDF's C flags to the Swift package build
        ├── Firmware/                # Next to the .xcodeproj in new projects
        │   ├── Firmware.swift       # Firmware entry point (app_main)
        │   ├── Board.swift          # The board's name, LED and button, from the Board pop-up
        │   ├── LED.swift            # Drives the board's LED, whatever kind it is
        │   ├── FreeRTOS.swift       # Swift versions of FreeRTOS's macros, such as pdMS_TO_TICKS
        │   ├── Package.swift        # The firmware package, built by ESP-IDF with SwiftPM
        │   └── ESPIDF/include/ESPIDF.h   # ESP-IDF's C APIs for Swift (import ESPIDF)
        ├── Kit/                     # Packages/<Project>Kit: plain Swift, tested on the Mac (Cmd+U)
        │   ├── Package.swift
        │   ├── Sources/Blink/
        │   └── Tests/BlinkTests/
        └── ButtonInput/, I2CSensor/, I2CDisplay/, WiFiRequest/, BLELight/, DeepSleep/   # The other examples' files
```

---

## System Requirements

- macOS: Xcode 26 or later, and a macOS version that runs it. The template is tested with Xcode 27.1 (earlier versions of it with Xcode 26.6 too); code completion needs Xcode 27.
- Linux: Ubuntu 24.04 or similar, with ESP-IDF's prerequisites and Swift 6.4 (see [Install](#install))
- Python, CMake and Git: on macOS, `espswift setup` installs any that are missing with [Homebrew](https://brew.sh) (Python 3.14, which ESP-IDF 6.1 supports; Homebrew's default Python may be newer); on Linux, Python 3.10 or newer
- EIM, which installs ESP-IDF: on macOS, Homebrew installs it with `espswift`, and `install.sh` installs it if it's missing; on Linux, install it yourself (see [Install](#install))
- About 10 GB of disk space: the Swift toolchain takes about 5 GB, ESP-IDF and its tools about 4 GB, and each project's build output about 250 MB
- An internet connection for installing, and for each project's first build (which downloads its ESP-IDF components)
- A board with a RISC-V based ESP32 chip (ESP32-C2, C3, C5, C6, C61, H2 or P4) and a USB connection

---

## What Gets Installed

`espswift setup` installs the following into your home directory:

| Path | Contents |
|------|----------|
| `~/.espswift/bin/espswift` | `espswift`, which projects build with: a link to Homebrew's, or (with `install.sh`) to a copy in `~/.espswift/libexec` |
| `~/.espressif/v6.1/` | ESP-IDF 6.1, installed with EIM (~700 MB) |
| `~/.espressif/tools/` | ESP-IDF's compilers, tools and Python environment, and EIM's list of installations, `eim_idf.json` (~3 GB) |
| `~/.espswift/python/` | Link to the Python that EIM makes ESP-IDF's Python environment with (3.14 on macOS) |
| `~/Library/Developer/Toolchains/` | macOS: the Swift 6.4.0 release toolchain (~5 GB), installed with [swiftly](https://www.swift.org/install/macos/) if you have it, otherwise from swift.org's installer. On Linux, swiftly's toolchain, or the Swift on your `PATH` |
| `~/.espswift/swift-toolchain` | Path of the Swift toolchain that projects use |
| `~/Library/Developer/Xcode/Templates/` | ESP32 RISC-V Xcode template (macOS) |

Nothing is installed to system directories. Everything is scoped to your user home directory.

### Updating ESPSwift

With Homebrew, run `brew upgrade espswift` (or, with `--HEAD`, `brew upgrade --fetch-HEAD espswift`), then `espswift setup`, which updates the Xcode template too. With a copy of this repository, update it and run `install.sh` again. Each project's `build.sh` only runs the `espswift` that `espswift setup` links (`~/.espswift/bin/espswift build`), so updating ESPSwift also updates how existing projects build.

When an update changes what projects need, the build shows a warning in Xcode's Issue navigator with the command that updates the project. You can also run it yourself, in the project's folder:

```bash
~/.espswift/bin/espswift update
```

It replaces the project's `build.sh` with the template's and points code completion at the Swift version `espswift setup` installed; it only changes what needs changing.

### Switching ESP-IDF versions

`espswift setup` installs a fixed ESP-IDF release (`Pins.espIDF` in `cli/Sources/EspSwiftCore/Versions.swift`) with EIM, next to any other versions EIM installed (`eim list`), and uses that one. When a new version of ESPSwift pins another release, [update ESPSwift](#updating-espswift) to install it. To use an ESP-IDF that EIM didn't install, set `IDF_PATH` to its folder.

If ESP-IDF's Python environment stops working, for instance after the Python it was made with was removed, `espswift doctor` says so, and `eim fix v6.1` repairs it.

Then, in each existing project, press `Cmd+Shift+K` followed by `Cmd+B` in Xcode. ESP-IDF updates the project's `sdkconfig` for the new version; review that change before committing it.

---

## Uninstall

To remove ESPSwift, run:

```bash
~/.espswift/bin/espswift uninstall
```

It removes `~/.espswift` (espswift itself) and the Xcode template. It then asks before removing things other projects may also use: the Swift toolchain (through swiftly, if you use it), ESP-IDF 6.1 (with `eim remove`), and ESP-IDF's component download cache. Use `--all` to remove those without asking, and `--yes` to skip the confirmation.

It never removes Homebrew or the packages installed with it (Python, CMake, EIM), other ESP-IDF versions, swiftly, or your projects.

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for what's planned next.

---

## Known Issues & Limitations

- Xcode's serial console is read-only (no interactive input); use `espswift monitor --idf` in Terminal
- The firmware package is built with SwiftPM's deprecated `--build-system native` (see [ROADMAP.md](ROADMAP.md))
- The very first lines a board prints after flashing can be missing in the serial output; press the board's RESET button to see them

See all open issues: [GitHub Issues](https://github.com/johankool/espswift/issues)

---

## License

MIT — see [LICENSE](LICENSE)

## References

- [Embedded Swift Documentation](https://www.swift.org/embedded/)
- [ESP-IDF Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32c6/)
- [ESP-IDF Component Registry](https://components.espressif.com)
- [ESP32-C6 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-c6_datasheet_en.pdf)
