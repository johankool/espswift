# Contributing to Embedded Swift Xcode Template

Thank you for your interest in contributing! This project aims to make Embedded Swift development on ESP32 as approachable as possible — contributions of all kinds are welcome.

## Ways to Contribute

- **Bug reports** — Found something broken? Open an issue.
- **Feature requests** — Have an idea? Open an issue and describe it.
- **Documentation** — Improve README, add examples, fix typos.
- **Code** — Fix bugs, add features, improve scripts.
- **Testing** — Try the installer on a different machine and report results.

---

## Getting Started

### 1. Fork and clone

```bash
git clone https://github.com/<your-username>/Embedded-Swift-Xcode-Template.git
cd Embedded-Swift-Xcode-Template
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

If you changed the template, `espswift` (`cli/`), a script in `scripts/` or `install.sh`, build a project from the template for every chip it offers:

```bash
bash tests/test_template.sh            # all chips
bash tests/test_template.sh esp32c6    # one chip
```

It creates each project the way Xcode does and builds it with the ESP-IDF and Swift toolchain `install.sh` installed (run `install.sh` first). Each chip takes about half a minute. GitHub Actions runs the same test for every pull request, after installing everything with `install.sh` on a fresh macOS runner.

The test doesn't cover Xcode or hardware, so for changes there, also check by hand:
- After running `install.sh` and restarting Xcode, **ESP32 RISC-V** appears under File → New → Project → Other, with the **Chip** pop-up.
- A new project's `sdkconfig.defaults` has the chip you picked, and `README.md` sits next to the `.xcodeproj`.
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
Embedded-Swift-Xcode-Template/
├── install.sh                        # Builds espswift and runs espswift setup
├── uninstall.sh                      # Removes what install.sh installed
├── cli/                              # espswift, ESPSwift's command-line tool (see cli/README.md)
├── tests/
│   └── test_template.sh             # Builds the template for every chip
├── .github/workflows/
│   └── build-template.yml           # Runs install.sh and the test in CI
├── scripts/
│   ├── build_package.py             # Builds a project's Swift package with SwiftPM
│   ├── run.sh                       # Cmd+R: flashes the last build, then starts the monitor
│   ├── debug.sh                     # Debugs the firmware on the board with LLDB
│   ├── detect_port.sh               # Auto-detects the connected board
│   ├── flash.sh                     # Flashes firmware via idf.py
│   ├── monitor.sh                   # Streams serial output
│   ├── monitor_wrapper.c            # Native binary wrapper for Xcode
│   ├── setup_scheme.sh              # Auto-configures Xcode Run scheme
│   ├── setup_indexing.sh            # Compiler settings for code completion
│   ├── indexing_flags.py            # (with SwiftPM's flags for the package)
│   ├── update_project.sh            # Updates projects created from an older template
│   └── add_library.sh               # Adds ESP-IDF component libraries
├── installer/
│   ├── build_pkg.sh                 # Builds .pkg installer
│   ├── build_dmg.sh                 # Builds .dmg disk image
│   ├── scripts/postinstall          # .pkg post-install script
│   └── ESPSwiftInstaller/           # SwiftUI installer app
└── Xcode Template/
└── ESP32 RISC-V.xctemplate/
├── TemplateInfo.plist
├── README.md
├── build.sh
├── scheme.xcscheme
├── CMakeLists.txt
├── sdkconfig.defaults
├── main/
│   ├── CMakeLists.txt
│   ├── idf_component.yml
│   └── swift_flags.c
├── Firmware/
│   ├── Firmware.swift
│   ├── Package.swift
│   ├── ESPIDF/include/ESPIDF.h
│   └── ESPIDF/ESPIDF.c
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

### Swift (ESPSwiftInstaller)
- Follow Swift API Design Guidelines
- All comments in **English**
- Use `@MainActor` for UI updates
- Prefer `async/await` over callbacks where possible

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):
feat: add GPIO example
fix: resolve CH340 port detection on macOS Ventura
docs: update README with serial monitor guide
chore: update .gitignore
refactor: simplify detect_port.sh

---

## Reporting Bugs

When opening a bug report, please include:

- macOS version
- Xcode version
- Board model and chip (e.g. ESP32-C6-DevKitC-1)
- USB interface (native USB-CDC / CH340 / CP210x)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs (build output, serial output, `/var/log/install.log`)

---

## Hardware Requirements for Testing

To fully test this project you need:
- A development board with a RISC-V based ESP32 chip, such as the ESP32-C6
- USB cable (USB-C or Micro-USB depending on board)
- macOS 12+ with Xcode 15+

If you don't have hardware, you can still contribute to:
- Documentation and README
- ESPSwiftInstaller SwiftUI app
- Shell script logic (without flash testing)

---

## Known Limitations

Before contributing, it helps to know the current limitations:

- Embedded Swift is experimental — not all Swift standard library features work
- Xcode's debug console is read-only (no serial input)

See all open issues: [GitHub Issues](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues)

---

## Questions?

Open an issue or start a discussion on GitHub. All questions are welcome!
