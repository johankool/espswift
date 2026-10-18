# Roadmap

Contributions to any of these are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Next

- [ ] **A Linux bottle,** so Homebrew on Linux installs a built espswift too, as it does on macOS with Apple Silicon. It needs Homebrew's Swift to build espswift, and EIM's formula on Linux. Then `install.sh`, which builds espswift from the repository, can go.

## Near-term

- [ ] **More tutorials,** such as one per example, next to Your First Firmware.

## Longer-term

- [ ] **Test the other chips and boards on hardware.** Only the ESP32-C6-DevKitC-1 has run firmware (each example, with a network for Wi-Fi, a phone for Bluetooth and an SSD1306 for the I2C display; only the I2C sensor example hasn't read a real SHT4x yet). The ESP32-C2, C3, C5, C61, H2 and P4 are tested by building only, as are the other boards' LEDs: the WS2812 over SPI on the C2 and C61, the ESP8684-DevKitM-1's separate red, green and blue LEDs (assumed lit by a high level), the XIAO ESP32C6's one-colour LED (assumed lit by a low level) and the NanoC6's LED power pin.
- [ ] **Build the Swift package with SwiftPM's default build system.** The firmware build uses `swift build --build-system native` (see `cli/Sources/EspSwiftCore/PackageBuild.swift`): Swift Build, SwiftPM's default since Swift 6.4, links C targets with Apple's linker, which can't link code for the ESP32. SwiftPM warns that the native build system is deprecated and will be removed, so this needs a fix in Swift Build, or a way around it, before then. Worth reporting to the SwiftPM project.
- [ ] **Cache downloads in CI.** Every CI run downloads and installs ESP-IDF, its tools and Swift (about 5 minutes of each run). Caching them between runs would make CI faster.
- [ ] `espswift-idf` Swift Package: idiomatic Swift wrappers for ESP-IDF APIs (GPIO, LED, timers, ...), so projects don't call C functions such as `led_strip_new_rmt_device` directly, as the template's `LED.swift` does

## Ideas

Not planned yet; worth considering.

**Keeping projects up to date**
- [ ] **A version check,** so users learn about new releases (`brew upgrade espswift` then updates).

**Running without hardware**
- [ ] **Run firmware in the [Wokwi](https://wokwi.com) simulator.** Wokwi simulates the ESP32-C3, C6, C61 and H2 (C5 in alpha, P4 in beta; see [its ESP32 guide](https://docs.wokwi.com/guides/esp32)). `Cmd+R` could run the firmware without a board, and the [Wokwi CLI](https://docs.wokwi.com/wokwi-ci/getting-started) could make CI check that it actually runs and prints the expected serial output, not just that it builds. Its free tier allows 50 minutes of simulation per 30 days.

**Debugging**
- [ ] **Debugging in Xcode's interface.** Debugging works with LLDB in Terminal (`espswift debug`). Xcode's own debugger refuses the firmware: a scheme's executable must be a Mac program ("Inappropriate file type or format"), also when waiting for it to launch. A remaining idea is a stand-in `debugserver` (set through `LLDB_DEBUGSERVER_PATH` from an LLDB init file) that relays Xcode's LLDB to OpenOCD, with a Mac stub as the scheme's executable.
- [ ] **`fatalError`'s message in crash backtraces.** Embedded Swift leaves the message out, so the backtrace says "fatal error".

**Everyday workflow**
- [ ] **Choose the serial port** in Xcode when several boards are connected; `espswift run` takes the first one it finds (in Terminal, `--port` chooses).
- [ ] **Show the firmware size after each build** (`idf.py size`), so growth is visible before it hits the flash limit.
- [ ] **Faster builds with ccache,** which ESP-IDF supports for its C code.
- [ ] **Code completion with Xcode 26.** Projects build without errors in Xcode 26.6, but code completion and jump to definition don't work there; they're verified with Xcode 27 only, and so is CI. A starting point: compare the compiler arguments the editor gets (`xcodebuild -target Indexing -showBuildSettingsForIndex -json`) in Xcode 26.6 and 27. Testing it in CI would also need a test fixture (`tests/fixtures/project.pbxproj`) created by Xcode 26.

**Quality and reach**
- [ ] **More checks in CI:** ShellCheck for `install.sh`, the template's `build.sh` and the test; `espswift setup`'s swiftly route (CI uses swift.org's installer on macOS and Swift's Docker image on Linux); the Homebrew formula; and `espswift uninstall`.
- [ ] **A VS Code and Cursor guide:** code completion there would need SourceKit-LSP pointed at the firmware build of the Swift package, and the CodeLLDB extension could debug with the same setup as `espswift debug`.

## Done

- [x] ESP32-C3 and other RISC-V chips (ESP32-C2, C5, C61, H2, P4)
- [x] Choose the board, not just the chip: one Board pop-up (Espressif's DevKits, Seeed Studio XIAO ESP32C6, M5Stack NanoC6, or Other with its chip) sets the chip, the LED and the flash size
- [x] The example blinks each board's own LED (addressable, separate red, green and blue, one-colour, or none), in Swift: `Board.swift` says which LED the board has and `LED.swift` drives it; `ESPIDF.h` only includes ESP-IDF's headers
- [x] ESP-IDF's settings as Swift compilation conditions (`#if CONFIG_SOC_RMT_SUPPORTED`), in the build and in code completion
- [x] Code completion and jump to definition in Xcode (Xcode 27)
- [x] Template build test, run in CI for every chip
- [x] `Cmd+B` only builds; `Cmd+R` flashes the board and shows its serial output
- [x] `Cmd+R` works in new projects without reopening them first ([#3](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues/3)), and flashes that project's build, also after building another project
- [x] Xcode's Project navigator shows the files you work with, and leaves out those you'd hardly ever change (`build.sh`, the `CMakeLists.txt` files, `.gitignore`, the scheme)
- [x] On-chip debugging with LLDB (`espswift debug`): breakpoints in Swift, backtraces and variables, through the built-in USB-JTAG
- [x] Crash backtraces in Xcode's console and `espswift monitor`: a crash's dump is decoded into Swift function names, files and lines, as ESP-IDF's monitor does
- [x] Each project's `build.sh` runs the installed `espswift build`, so updating ESPSwift updates the build of every project
- [x] Projects carry a template version; the build warns when a project is out of date (older template, or code completion on an older Swift), and `espswift update` updates it
- [x] Build errors and warnings (Swift, C, CMake, `sdkconfig.defaults`) in Xcode's Issue navigator, linked to their line; the build log leaves out ESP-IDF's other output
- [x] The Swift code is in Swift packages: the firmware can use Embedded-compatible Swift packages (such as `swift-mmio`), and code that doesn't use ESP-IDF is in a package of the project that Xcode tests on the Mac (`Cmd+U`)
- [x] `espswift`, ESPSwift's command-line tool, in Swift: `setup`, `new`, `build`, `run`, `flash`, `monitor`, `debug`, `add`, `settings`, `update`, `doctor` and `uninstall`, on macOS and Linux; it replaces the shell and Python scripts and the SwiftUI installer (see [cli/README.md](cli/README.md))
- [x] `espswift new` creates projects without Xcode
- [x] Examples to start a project from, in the template's Example pop-up and `espswift new --example`, built and tested by CI: Blink, Button input (GPIO input with debouncing), I2C sensor (an SHT4x), I2C display (an SSD1306), Wi-Fi and HTTPS, Bluetooth LE light (a GATT server with NimBLE), Matter light (Apple Home, with esp-matter and C++ interoperability) and Deep sleep (a timer wake-up and RTC memory); `espswift new` asks for the board and the example
- [x] ESP-IDF is installed with EIM, Espressif's ESP-IDF Installation Manager, and shared with Espressif's other tools
- [x] A Homebrew tap, [johankool/homebrew-espswift](https://github.com/johankool/homebrew-espswift), with a bottle for macOS on Apple Silicon (`brew install espswift`), built and published by the tap's CI; the first releases, 0.2.0 and 0.2.1
- [x] A DocC tutorial, [Your First Firmware](https://johankool.github.io/espswift/tutorials/espswift/your-first-firmware) (`Documentation/ESPSwift.docc`): set up, create a project, run it, change it and test it on the Mac; CI builds it, checks it starts from the template's files, and publishes it on GitHub Pages
- [x] Linux: espswift sets up, creates, builds and tests projects on Linux; the template test runs there too (a CI job)
