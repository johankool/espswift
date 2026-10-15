# Roadmap

This project is being developed as part of the [Swift Mentorship Program](https://www.swift.org/mentorship/). Contributions to any of these are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Near-term

- [ ] **Code completion with Xcode 26.** Projects build without errors in Xcode 26.6, but code completion and jump to definition don't work there; they're verified with Xcode 27 only, and so is CI. A starting point: compare the compiler arguments the editor gets (`xcodebuild -target Indexing -showBuildSettingsForIndex -json`) in Xcode 26.6 and 27. Testing it in CI would also need a test fixture (`tests/fixtures/project.pbxproj`) created by Xcode 26.
- [ ] **Build the Swift package with SwiftPM's default build system.** The firmware build uses `swift build --build-system native` (see `scripts/build_package.py`): Swift Build, SwiftPM's default since Swift 6.4, links C targets with Apple's linker, which can't link code for the ESP32. SwiftPM warns that the native build system is deprecated and will be removed, so this needs a fix in Swift Build, or a way around it, before then. Worth reporting to the SwiftPM project.
- [ ] **Test the other chips on hardware.** Only the ESP32-C6 has run on a board. The ESP32-C2, C3, C5, C61, H2 and P4 are tested by building only, including the per-chip LED pins and the LED over SPI on the C2 and C61.
- [ ] **Cache downloads in CI.** Every CI run downloads and installs ESP-IDF, its tools and Swift (about 5 of its 11 minutes). Caching them between runs would make CI faster.
- [ ] Signed and notarized installer
- [ ] GPIO and I2C sensor examples
- [ ] Installer progress bar improvements ([#4](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues/4))

## Longer-term

- [ ] `espswift-idf` Swift Package: idiomatic Swift wrappers for ESP-IDF APIs (GPIO, LED, timers, ...), so projects don't call C functions such as `led_strip_new_rmt_device` directly
- [ ] `espswift` CLI, written in Swift and installed with Homebrew, replacing `install.sh` and the scripts, on macOS and Linux. In progress: see [cli/README.md](cli/README.md) for the plan; so far `espswift doctor` and `espswift ports`.
- [ ] Homebrew tap
- [ ] ESP32-S3 support (needs Xtensa support in Swift)

## Ideas

Not planned yet; worth considering.

**Keeping projects up to date**
- [ ] **`install.sh --update` or a version check,** so users learn about new releases.

**Running without hardware**
- [ ] **Run firmware in the [Wokwi](https://wokwi.com) simulator.** Wokwi simulates the ESP32-C3, C6, C61 and H2 (C5 in alpha, P4 in beta; see [its ESP32 guide](https://docs.wokwi.com/guides/esp32)). `Cmd+R` could run the firmware without a board, and the [Wokwi CLI](https://docs.wokwi.com/wokwi-ci/getting-started) could make CI check that it actually runs and prints the expected serial output, not just that it builds. Its free tier allows 50 minutes of simulation per 30 days.

**Debugging**
- [ ] **Debugging in Xcode's interface.** Debugging works with LLDB in Terminal (`debug.sh`). Xcode's own debugger refuses the firmware: a scheme's executable must be a Mac program ("Inappropriate file type or format"), also when waiting for it to launch. A remaining idea is a stand-in `debugserver` (set through `LLDB_DEBUGSERVER_PATH` from an LLDB init file) that relays Xcode's LLDB to OpenOCD, with a Mac stub as the scheme's executable.
- [ ] **Decode crash backtraces:** turn the addresses in a panic dump into file and line numbers in the Xcode console, as ESP-IDF's monitor does.

**Everyday workflow**
- [ ] **Choose the serial port** when several boards are connected; `detect_port.sh` picks the first one it finds.
- [ ] **Interactive serial input:** Xcode's console is output-only; a "Monitor in Terminal" action could open the serial monitor in Terminal for two-way communication.
- [ ] **Show the firmware size after each build** (`idf.py size`), so growth is visible before it hits the flash limit.
- [ ] **Faster builds with ccache,** which ESP-IDF supports for its C code.
- [ ] **Choose the board, not just the chip:** a Board pop-up (e.g. ESP32-C6-DevKitC-1 or DevKitM-1) could set the LED pin and flash size together.

**Examples and libraries**
- [ ] **Example projects:** Wi-Fi with an HTTP request, BLE, an I2C sensor, deep sleep; each a small project in an `Examples/` folder that CI builds as well.

**Quality and reach**
- [ ] **More checks in CI:** ShellCheck for the scripts, `uninstall.sh`, and `install.sh`'s swiftly route (CI only uses swift.org's installer).
- [ ] **A VS Code and Cursor guide:** code completion there would need SourceKit-LSP pointed at the firmware build of the Swift package, and the CodeLLDB extension could debug with the same setup as `debug.sh`; also a step toward Linux support.
- [ ] **A documentation site:** a DocC tutorial ("your first firmware") built around the template.

## Done

- [x] ESP32-C3 and other RISC-V chips (ESP32-C2, C5, C61, H2, P4)
- [x] Code completion and jump to definition in Xcode (Xcode 27)
- [x] Template build test, run in CI for every chip
- [x] `Cmd+B` only builds; `Cmd+R` flashes the board and shows its serial output
- [x] `Cmd+R` works in new projects without reopening them first ([#3](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template/issues/3))
- [x] On-chip debugging with LLDB (`debug.sh`): breakpoints in Swift, backtraces and variables, through the built-in USB-JTAG
- [x] Each project's `build.sh` calls ESPSwift's installed build script, so updating ESPSwift updates the build of every project created from then on
- [x] Projects carry a template version; the build warns when a project is out of date (older template, or code completion on an older Swift), and `update_project.sh` updates it
- [x] Build errors and warnings (Swift, C, CMake, `sdkconfig.defaults`) in Xcode's Issue navigator, linked to their line; the build log leaves out ESP-IDF's other output
- [x] The Swift code is in Swift packages: the firmware can use Embedded-compatible Swift packages (such as `swift-mmio`), and code that doesn't use ESP-IDF is in a package of the project that Xcode tests on the Mac (`Cmd+U`)
