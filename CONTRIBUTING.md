# Contributing to ESPSwift

Thank you for your interest in contributing! This project aims to make Embedded Swift development on ESP32 as approachable as possible — contributions of all kinds are welcome.

## Ways to Contribute

- **Bug reports** — Found something broken? Open an issue.
- **Feature requests** — Have an idea? Open an issue and describe it.
- **Documentation** — Improve README, add examples, fix typos.
- **Code** — Fix bugs, add features, improve `espswift` and the template.
- **Testing** — Try ESPSwift on a different machine (or Linux distribution) and report results.

---

## Getting Started

### 1. Fork and clone

```bash
git clone https://github.com/<your-username>/espswift.git
cd espswift
```

### 2. Set up your environment

```bash
bash install.sh
```

### 3. Create a branch

```bash
git checkout -b your-feature-name
```

### 4. Make your changes and test them

If you changed `espswift`, run its unit tests:

```bash
swift test --package-path cli
```

If you changed the template, `espswift` or `install.sh`, build a project from the template for every chip it offers:

```bash
bash tests/test_template.sh            # all chips
bash tests/test_template.sh esp32c6    # one chip
```

If you changed the template or `espswift`, also build the template's examples (the Example pop-up) and run their tests:

```bash
bash tests/test_template.sh --examples                       # every example, and some on other chips
bash tests/test_template.sh --examples deep-sleep            # one example, on the default board
bash tests/test_template.sh --examples deep-sleep@esp32c2    # one example, on a chip
```

It builds espswift from `cli/`, creates each project with `espswift new` (which lays it out the way Xcode does) and builds it with the ESP-IDF (installed with EIM) and Swift toolchain `espswift setup` installed (run `install.sh` first). Each chip takes about half a minute. On Linux, without Xcode, it checks the builds, their error reporting and the Kit package's tests. With `--examples` it creates a project from each example instead (other than Blink, which every chip is built with), and also checks that its build has no warnings. GitHub Actions runs the CLI's tests (`cli.yml`) and the template and examples tests (`build-template.yml`) for every pull request, on macOS and Linux, after setting up everything on a fresh runner, and builds the tutorial (`docs.yml`).

The test doesn't cover Xcode or hardware, so for changes there, also check by hand:
- After running `install.sh` and restarting Xcode, **ESP32 RISC-V** appears under File → New → Project → Choose Template… → Other, with the **Board** and **Example** pop-ups.
- A new project's `sdkconfig.defaults` has the chip and flash size of the board you picked, it has the example's files, `README.md` sits next to the `.xcodeproj`, and the Project navigator leaves out `build.sh`, the `CMakeLists.txt` files, `main/swift_flags.c`, `.gitignore` and the scheme.
- `Cmd+B` builds without flashing, and `Cmd+R` flashes your board and shows its serial output (also after building another project: it flashes this project's build).
- After that first build, code completion works in `Firmware/Firmware.swift` (e.g. typing `led_strip_` or `blinkStep`), `Cmd+U` runs the Kit package's tests, and Command-clicking `vTaskDelay` opens FreeRTOS's `task.h`.

### The tutorial

The DocC tutorial is in `Documentation/ESPSwift.docc`: its pages (`*.tutorial`) and, in `Resources/`, the files its steps show. Its `-01` files are those a new project from the Blink example has; later steps change them. Preview it with `xcrun docc preview Documentation/ESPSwift.docc`, and check it with:

```bash
bash tests/check_tutorial.sh
```

which builds it with warnings as errors and fails if the template's files no longer match the tutorial's. CI runs it (`docs.yml`), and publishes the tutorial from `main` on [GitHub Pages](https://johankool.github.io/espswift/tutorials/espswift).

### Examples

The template's **Example** pop-up chooses what a new project starts from. Each example is a value of the pop-up, in `TemplateInfo.plist`, with:
- its files (its *Units*: nodes and definitions, which only that value adds): `Firmware/Firmware.swift`, the Kit package and `ESPIDF.h`, and any other files in `Firmware/`. Blink's are the template's own files; the other examples' are in a folder of their own, such as `ButtonInput/`, named as the template names files (`Firmware_WiFi.swift` for `Firmware/WiFi.swift`);
- its variables: its title, its Kit module (`exampleModule`, which the Firmware package and the scheme's tests use), a one-sentence summary for the README, its lines for `sdkconfig.defaults`, and its ESP-IDF libraries for `main/idf_component.yml` (`exampleComponents`).

The Matter light also has a `Package.swift` of its own, which turns on C++ interoperability for esp-matter's C++ API, and C++ in `main/`, which ESP-IDF compiles: its `uint32_t` is an `unsigned long`, where Swift's Clang has an `unsigned int`, so functions that take one need a small C++ function that Swift calls instead.

The board's variables give an example its pins: `boardButton` (in `Board.swift`), and `boardI2CSDA` and `boardI2CSCL`. An example that needs something a chip lacks checks for it with `#if` (such as `CONFIG_SOC_WIFI_SUPPORTED`) and says so. For a new example, add it to the table in README.md's Examples, and a combination such as `wifi-request@esp32h2` to `EXAMPLE_COMBINATIONS` in `tests/test_template.sh` if it uses something not every chip has.

### 5. Commit

```bash
git add .
git commit -m "Describe what you did"
```

### 6. Push and open a Pull Request

```bash
git push origin your-feature-name
```

Then open a PR on GitHub against the `main` branch.

---

## Project Structure

```
espswift/
├── install.sh                        # Builds espswift and runs espswift setup
├── cli/                              # espswift, ESPSwift's command-line tool (see cli/README.md)
│   ├── Package.swift
│   ├── Sources/espswift/            # The commands (swift-argument-parser)
│   ├── Sources/EspSwiftCore/        # What they do, through the System protocol
│   ├── Sources/CSerialPort/         # Opening serial ports (needs C)
│   └── Tests/EspSwiftCoreTests/     # Unit tests, with a fake System
├── Documentation/ESPSwift.docc/      # The DocC tutorial: its pages, and its files and images in Resources/
├── tests/
│   ├── test_template.sh             # Builds the template for every chip, or its examples (--examples)
│   ├── xcode_project.py             # Writes a test project's Xcode project, from the fixture
│   ├── check_tutorial.sh            # Builds the DocC tutorial and checks it against the template
│   └── fixtures/project.pbxproj     # An Xcode project Xcode made from the template
├── .github/workflows/
│   ├── cli.yml                      # Builds and tests espswift, on macOS and Linux
│   ├── build-template.yml           # Sets up ESPSwift and runs the template and examples tests, on macOS and Linux
│   └── docs.yml                     # Builds the tutorial and checks it against the template
└── Xcode Template/
    └── ESP32 RISC-V.xctemplate/
        ├── TemplateInfo.plist
        ├── README.md
        ├── build.sh
        ├── scheme.xcscheme
        ├── CMakeLists.txt
        ├── sdkconfig.defaults
        ├── gitignore                # .gitignore, at the project's root
        ├── main_CMakeLists.txt, main_idf_component.yml, main_swift_flags.c   # main/
        ├── Firmware_Firmware.swift, Firmware_Board.swift, Firmware_LED.swift, Firmware_FreeRTOS.swift, Firmware_Package.swift   # Firmware/
        ├── ESPIDF_ESPIDF.h, ESPIDF_ESPIDF.c                                 # Firmware/ESPIDF/
        ├── Kit/                     # Packages/<Project>Kit (Blink's, and Deep sleep's)
        │   ├── Package.swift
        │   ├── Sources/Blink/Blink.swift
        │   └── Tests/BlinkTests/BlinkTests.swift
        └── ButtonInput/, I2CSensor/, I2CDisplay/, WiFiRequest/, BLELight/, MatterLight/, DeepSleep/   # The other examples' files (see Examples)
```

---

## Coding Guidelines

### Shell Scripts
- Use `#!/bin/bash` shebang
- Add `set -e` for scripts where partial failure is unacceptable
- Comment every non-obvious section
- All comments and output in **English**
- Use `$HOME` instead of `~` in paths (more portable)
- Test on both Intel and Apple Silicon if possible

### Swift (espswift)
- Follow Swift API Design Guidelines
- All comments in **English**
- Reach files, the environment and programs only through the `System` protocol, so the commands can be tested with `FakeSystem`; add a test for what you change
- Don't assume a Mac: espswift runs on macOS and Linux (no `PlistBuddy`, `xcrun` or `sed -i ''` outside macOS-only code)
- Errors for the user are `EspSwiftError`s, which say what to do

---

## Reporting Bugs

When opening a bug report, please include:

- macOS version and Xcode version (or Linux distribution)
- Board model and chip (e.g. ESP32-C6-DevKitC-1)
- USB interface (native USB-CDC / CH340 / CP210x)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs (build output, serial output, `espswift doctor`'s output)

---

## Hardware Requirements for Testing

To fully test this project you need:
- A development board with a RISC-V based ESP32 chip, such as the ESP32-C6
- USB cable (USB-C or Micro-USB depending on board)
- macOS with Xcode 26 or later, or Linux

If you don't have hardware, you can still contribute to:
- Documentation and README
- `espswift`, most of which is tested without hardware
- The template (`tests/test_template.sh` builds it for every chip)

---

## Known Limitations

Before contributing, it helps to know the current limitations:

- Embedded Swift is experimental — not all Swift standard library features work
- Xcode's debug console is read-only (no serial input)

See all open issues: [GitHub Issues](https://github.com/johankool/espswift/issues)

---

## Questions?

Open an issue or start a discussion on GitHub. All questions are welcome!
