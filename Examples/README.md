# Examples

Small projects that each show one thing, in Embedded Swift on a RISC-V ESP32. Each is a project as the Xcode template creates it, for the **ESP32-C6-DevKitC-1**, with its own README: what it does, what to wire, and how to run it on another board.

| Example | What it shows |
| --- | --- |
| [ButtonInput](ButtonInput) | Reading a GPIO pin: the BOOT button changes the LED's colour, with debouncing tested on the Mac |
| [I2CSensor](I2CSensor) | An I2C sensor: temperature and humidity from a Sensirion SHT4x, with its checksums and conversions tested on the Mac |
| [WiFiRequest](WiFiRequest) | Wi-Fi and an HTTPS request, with ESP-IDF's events and certificate bundle; lists the networks nearby until you set yours |
| [BLELight](BLELight) | A Bluetooth LE GATT server with NimBLE: a phone sets the LED's colour |
| [DeepSleep](DeepSleep) | Deep sleep with a timer wake-up, and a variable in RTC memory that survives it |

## Running an example

1. Install ESPSwift and run `espswift setup` (see [the README](../README.md)).
2. In Terminal, in the example's folder, run `~/.espswift/bin/espswift update`. It points the example's Xcode project at your Swift toolchain (for code completion) and at espswift (for `Cmd+R`), as Xcode does for a project you create from the template.
3. Open the example's `.xcodeproj` and press `Cmd+R`. Or, without Xcode (also on Linux), run `~/.espswift/bin/espswift run` in its folder.

To start a project of your own from an example, copy its folder; to rename it, it's easier to create a new project and copy the example's Swift files into it.

## How they're made

Each example was created with `espswift new <name> --board esp32-c6-devkitc-1 --folder Examples`, and then changed. Their Xcode projects are written by `tests/xcode_project.py`, as only Xcode creates projects from the template; run it again after adding a Swift file to an example's `Firmware` folder. CI builds every example and runs its tests (`bash tests/test_template.sh --examples`); see [CONTRIBUTING.md](../CONTRIBUTING.md).
