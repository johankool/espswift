# Roadmap

This project is being developed as part of the [Swift Mentorship Program](https://www.swift.org/mentorship/). Contributions to any of these are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Before the first release

- [ ] **Bring `main` up to date.** The work since the Swift packages (espswift, EIM, the Board pop-up, crash backtraces, the LED in Swift) is on the `feature/espswift-cli` branch. CI hasn't run on it yet; in particular EIM's install on fresh runners (Homebrew on macOS, its release on Linux) is only tested locally.
- [ ] **Rename the repository to `johankool/espswift`** on GitHub, and publish the Homebrew tap, [johankool/homebrew-espswift](https://github.com/johankool/homebrew-espswift), whose formula builds espswift from `main`.
- [ ] **Releases.** A release workflow that builds espswift for macOS and Linux, so the formula installs a release instead of building `main` (`--HEAD`, which needs Xcode). Then `install.sh`, which builds espswift from the repository, can go.

## Near-term

- [ ] **Test the other chips and boards on hardware.** Only the ESP32-C6-DevKitC-1 has run firmware. The ESP32-C2, C3, C5, C61, H2 and P4 are tested by building only, as are the other boards' LEDs: the WS2812 over SPI on the C2 and C61, the ESP8684-DevKitM-1's separate red, green and blue LEDs (assumed lit by a high level), the XIAO ESP32C6's one-colour LED (assumed lit by a low level) and the NanoC6's LED power pin.
- [ ] **Code completion with Xcode 26.** Projects build without errors in Xcode 26.6, but code completion and jump to definition don't work there; they're verified with Xcode 27 only, and so is CI. A starting point: compare the compiler arguments the editor gets (`xcodebuild -target Indexing -showBuildSettingsForIndex -json`) in Xcode 26.6 and 27. Testing it in CI would also need a test fixture (`tests/fixtures/project.pbxproj`) created by Xcode 26.
- [ ] **Build the Swift package with SwiftPM's default build system.** The firmware build uses `swift build --build-system native` (see `cli/Sources/EspSwiftCore/PackageBuild.swift`): Swift Build, SwiftPM's default since Swift 6.4, links C targets with Apple's linker, which can't link code for the ESP32. SwiftPM warns that the native build system is deprecated and will be removed, so this needs a fix in Swift Build, or a way around it, before then. Worth reporting to the SwiftPM project.
- [ ] **Cache downloads in CI.** Every CI run downloads and installs ESP-IDF, its tools and Swift (about 5 of its 11 minutes). Caching them between runs would make CI faster.
- [ ] **Example projects:** GPIO input, an I2C sensor, Wi-Fi with an HTTP request, BLE, deep sleep; each a small project in an `Examples/` folder that CI builds as well.

## Longer-term

- [ ] `espswift-idf` Swift Package: idiomatic Swift wrappers for ESP-IDF APIs (GPIO, LED, timers, ...), so projects don't call C functions such as `led_strip_new_rmt_device` directly, as the template's `LED.swift` does
- [ ] ESP32-S3 support (needs Xtensa support in Swift)

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
- [ ] **Interactive serial input:** Xcode's console is output-only; a "Monitor in Terminal" action could open the serial monitor in Terminal for two-way communication.
- [ ] **Show the firmware size after each build** (`idf.py size`), so growth is visible before it hits the flash limit.
- [ ] **Faster builds with ccache,** which ESP-IDF supports for its C code.

**Quality and reach**
- [ ] **More checks in CI:** ShellCheck for `install.sh`, the template's `build.sh` and the test; `espswift setup`'s swiftly route (CI uses swift.org's installer on macOS and Swift's Docker image on Linux); the Homebrew formula; and `espswift uninstall`.
- [ ] **A VS Code and Cursor guide:** code completion there would need SourceKit-LSP pointed at the firmware build of the Swift package, and the CodeLLDB extension could debug with the same setup as `espswift debug`.
- [ ] **A documentation site:** a DocC tutorial ("your first firmware") built around the template.

## Done

- [x] ESP32-C3 and other RISC-V chips (ESP32-C2, C5, C61, H2, P4)
- [x] Choose the board, not just the chip: one Board pop-up (Espressif's DevKits, Seeed Studio XIAO ESP32C6, M5Stack NanoC6, or Other with its chip) sets the chip, the LED and the flash size
- [x] The example blinks each board's own LED (addressable, separate red, green and blue, one-colour, or none), in Swift: `Board.swift` says which LED the board has and `LED.swift` drives it; `ESPIDF.h` only includes ESP-IDF's headers
- [x] ESP-IDF's settings as Swift compilation conditions (`#if CONFIG_SOC_RMT_SUPPORTED`), in the build and in code completion
- [x] Code completion and jump to definition in Xcode (Xcode 27)
- [x] Template build test, run in CI for every chip
- [x] `Cmd+B` only builds; `Cmd+R` flashes the board and shows its serial output
- [x] `Cmd+R` works in new projects without reopening them first ([#3](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues/3))
- [x] On-chip debugging with LLDB (`espswift debug`): breakpoints in Swift, backtraces and variables, through the built-in USB-JTAG
- [x] Crash backtraces in Xcode's console and `espswift monitor`: a crash's dump is decoded into Swift function names, files and lines, as ESP-IDF's monitor does
- [x] Each project's `build.sh` runs the installed `espswift build`, so updating ESPSwift updates the build of every project
- [x] Projects carry a template version; the build warns when a project is out of date (older template, or code completion on an older Swift), and `espswift update` updates it
- [x] Build errors and warnings (Swift, C, CMake, `sdkconfig.defaults`) in Xcode's Issue navigator, linked to their line; the build log leaves out ESP-IDF's other output
- [x] The Swift code is in Swift packages: the firmware can use Embedded-compatible Swift packages (such as `swift-mmio`), and code that doesn't use ESP-IDF is in a package of the project that Xcode tests on the Mac (`Cmd+U`)
- [x] `espswift`, ESPSwift's command-line tool, in Swift: `setup`, `new`, `build`, `run`, `flash`, `monitor`, `debug`, `add`, `settings`, `update`, `doctor` and `uninstall`, on macOS and Linux; it replaces the shell and Python scripts and the SwiftUI installer (see [cli/README.md](cli/README.md))
- [x] `espswift new` creates projects without Xcode
- [x] ESP-IDF is installed with EIM, Espressif's ESP-IDF Installation Manager, and shared with Espressif's other tools
- [x] A Homebrew tap (`brew install --HEAD espswift`), tested locally
- [x] Linux: espswift sets up, creates, builds and tests projects on Linux; the template test runs there too (a CI job)
