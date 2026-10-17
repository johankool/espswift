# Contributing to Embedded Swift Xcode Template

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
git checkout -b feat/your-feature-name
# or
git checkout -b fix/your-bug-fix
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

It builds espswift from `cli/`, creates each project with `espswift new` (which lays it out the way Xcode does) and builds it with the ESP-IDF (installed with EIM) and Swift toolchain `espswift setup` installed (run `install.sh` first). Each chip takes about half a minute. On Linux, without Xcode, it checks the builds, their error reporting and the Kit package's tests. GitHub Actions runs the CLI's tests (`cli.yml`) and the template test (`build-template.yml`) for every pull request, on macOS and Linux, after setting up everything on a fresh runner.

The test doesn't cover Xcode or hardware, so for changes there, also check by hand:
- After running `install.sh` and restarting Xcode, **ESP32 RISC-V** appears under File → New → Project → Choose Template… → Other, with the **Board** pop-up.
- A new project's `sdkconfig.defaults` has the chip and flash size of the board you picked, and `README.md` sits next to the `.xcodeproj`.
- `Cmd+B` builds without flashing, and `Cmd+R` flashes your board and shows its serial output.
- After that first build, code completion works in `Firmware/Firmware.swift` (e.g. typing `led_strip_` or `blinkStep`), `Cmd+U` runs the Kit package's tests, and Command-clicking `vTaskDelay` opens FreeRTOS's `task.h`.

### 5. Commit

```bash
git add .
git commit -m "feat: describe what you did"
```

### 6. Push and open a Pull Request

```bash
git push origin feat/your-feature-name
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
├── tests/
│   ├── test_template.sh             # Builds the template for every chip
│   └── fixtures/project.pbxproj     # An Xcode project Xcode made from the template
├── .github/workflows/
│   ├── cli.yml                      # Builds and tests espswift, on macOS and Linux
│   └── build-template.yml           # Sets up ESPSwift and runs the template test, on macOS and Linux
└── Xcode Template/
    └── ESP32 RISC-V.xctemplate/
        ├── TemplateInfo.plist
        ├── README.md
        ├── build.sh
        ├── scheme.xcscheme
        ├── CMakeLists.txt
        ├── sdkconfig.defaults
        ├── main_CMakeLists.txt, main_idf_component.yml, main_swift_flags.c   # main/
        ├── Firmware_Firmware.swift, Firmware_Package.swift                  # Firmware/
        ├── ESPIDF_ESPIDF.h, ESPIDF_ESPIDF.c                                 # Firmware/ESPIDF/
        └── Kit/                     # Packages/<Project>Kit
            ├── Package.swift
            ├── Sources/Blink/Blink.swift
            └── Tests/BlinkTests/BlinkTests.swift
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

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):
feat: add GPIO example
fix: resolve CH340 port detection on macOS Ventura
docs: update README with serial monitor guide
chore: update .gitignore
refactor: simplify port detection

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
