# WiFiRequest

Connects to a Wi-Fi network and requests a web page over HTTPS: GitHub's API, which answers with a short quote. The LED shows how it's going: blue while connecting, green when the request succeeded, red when something failed. Until you set your network's name and password, it lists the Wi-Fi networks nearby instead.

It shows how Swift uses ESP-IDF's Wi-Fi driver, network interface and event loop, with a Swift closure as the C event handler and a FreeRTOS event group to wait for the connection, and ESP-IDF's HTTP client, which checks the server's certificate with ESP-IDF's certificate bundle. One C macro, `WIFI_INIT_CONFIG_DEFAULT()`, fills in a struct, which Swift can't do; `ESPIDF.h` wraps it in a function.

## Running it

The example is made for the **ESP32-C6-DevKitC-1** (see [Another board](#another-board) for others).

1. Install ESPSwift and run `espswift setup` (see [ESPSwift's README](../../README.md)).
2. In Terminal, in this folder, run:

   ```bash
   ~/.espswift/bin/espswift update
   ```

   This points the Xcode project at your Swift toolchain (for code completion) and at espswift (for `Cmd+R`); a project you create from the template has both already.
3. Open `WiFiRequest.xcodeproj` and press `Cmd+R`, or in Terminal, run `~/.espswift/bin/espswift run`.

## Wiring

No wiring. Set your network's name and password in `Firmware/Credentials.swift`; the ESP32-C6 connects to 2.4 GHz networks.

## What's where

- `Firmware/Credentials.swift`: your network's name and password. Don't commit them to a public repository.
- `Firmware/WiFi.swift`: starting Wi-Fi, listing networks and connecting.
- `Firmware/HTTPS.swift`: the request.
- `Firmware/Firmware.swift`: puts them together.
- `Packages/WiFiRequestKit/Sources/Network/Network.swift`: IP addresses and C strings as text, and their tests in `Tests/NetworkTests`.
- `WiFiRequest/sdkconfig.defaults`: a larger app partition, as Wi-Fi and HTTPS make the firmware about 950 KB.

## Another board

The board's LED and the pins the example uses are in `Firmware/Board.swift`; its chip and flash size are in `WiFiRequest/sdkconfig.defaults` (see [Changing the chip](#changing-the-chip)). The [template's TemplateInfo.plist](../../Xcode%20Template/ESP32%20RISC-V.xctemplate/TemplateInfo.plist) has the LED of each board it knows. The ESP32-H2 and ESP32-P4 have no Wi-Fi; the ESP32-C2, C3, C5, C6 and C61 do.

---

The rest of this README is the one every project created from the template has.

## Everyday use in Xcode

| Shortcut | What it does |
| --- | --- |
| `Cmd+B` | Builds the firmware |
| `Cmd+R` | Builds, flashes the firmware to the connected board, and shows its serial output in Xcode's console |
| `Cmd+Shift+K` | Cleans the build |

**Product ▸ Perform Action ▸ Run Without Building** flashes whatever was built last, even if that was another project.

Errors and warnings from the build, in Swift, C, `CMakeLists.txt` and `sdkconfig.defaults`, appear in the Issue navigator (`Cmd+5`); click one to jump to its line. The build log shows only those and the firmware size; ESP-IDF's full output is in the build folder, in `log/build-output.log` (the build log names it when a build fails). To see all of it in the build log, add a user-defined build setting `ESPSWIFT_VERBOSE` = `1` to the WiFiRequest target.

## What's in this project

Your Swift code is in two Swift packages:

- **Firmware**: the firmware itself, `app_main` and the code that uses ESP-IDF. ESP-IDF builds it (with the Swift Package Manager) into the firmware. Xcode gives it code completion for ESP-IDF's C APIs (see below).
- **WiFiRequestKit**, in `Packages/`: plain Swift code that doesn't use ESP-IDF, such as the blink pattern in `Blink`, and its tests. The firmware uses it, and Xcode builds and tests it on the Mac (`Cmd+U`).

```
WiFiRequest/
├── README.md                   # This file
├── WiFiRequest.xcodeproj
├── Firmware/
│   ├── Firmware.swift          # Your firmware code starts here (app_main)
│   ├── Board.swift             # Your board's name and LED
│   ├── LED.swift               # Drives the LED, whatever kind it is
│   ├── FreeRTOS.swift          # Swift versions of FreeRTOS's macros, such as pdMS_TO_TICKS
│   ├── Package.swift           # The firmware's packages, such as swift-mmio
│   └── ESPIDF/include/
│       └── ESPIDF.h            # ESP-IDF's C APIs for Swift: `import ESPIDF`
├── Packages/
│   └── WiFiRequestKit/    # Plain Swift code, tested on the Mac
│       ├── Package.swift
│       ├── Sources/Blink/      # The blink pattern
│       └── Tests/BlinkTests/   # Its tests: Cmd+U
└── WiFiRequest/           # The ESP-IDF project (the "source folder")
    ├── build.sh                # Run by Xcode on Cmd+B: runs espswift build
    ├── CMakeLists.txt          # ESP-IDF project file
    ├── sdkconfig.defaults      # The chip and your ESP-IDF settings
    ├── sdkconfig               # Full ESP-IDF settings, created on first build
    ├── .espswift/              # Compiler settings for code completion, created by every build (hidden)
    └── main/
        ├── idf_component.yml   # ESP-IDF libraries this project depends on
        └── CMakeLists.txt      # Builds the Firmware package and links it into the firmware
```

To add Swift code to the firmware, create a file in `Firmware/` (also in a subfolder), and tick the **Indexing** target in the dialog for the new file so it gets code completion (see below). It's compiled into your firmware on the next `Cmd+B`; there's no list of files to update.

Code that doesn't need ESP-IDF can go in the Kit package instead, where you can test it. Create files in a folder in its `Sources/`, such as `Sources/Blink/`, with File ▸ New ▸ File from Template in Xcode. A new folder there is a new module: add it to the Kit's `Package.swift`, next to `Blink`, and to the Firmware package's `Package.swift`, next to `Blink`, to use it in the firmware. Code in the Kit package is built into the firmware too, so it must work in Embedded Swift.

Xcode keeps the build output in DerivedData, like any other Xcode project. **Product ▸ Show Build Folder in Finder** takes you there.

## Code completion

Code completion, jump to definition (Command-click) and inline errors work for your Swift code and for ESP-IDF's C APIs, **after the first `Cmd+B`**: the build provides Xcode with ESP-IDF's compiler settings, and updates them on every build.

This is what the project's second target, **Indexing**, is for. Xcode doesn't index the main target, because ESP-IDF builds it, so it indexes the Indexing target instead. You never need to build it or choose its scheme.

The Indexing target contains the Swift files in `Firmware/`. For a file there that doesn't get completion, select it and tick **Indexing** under **Target Membership** in the File inspector. The Kit package gets code completion from Xcode itself, like any Swift package.

## Testing on the Mac

Code in the Kit package can be tested on the Mac, without a board. Its tests, in `Packages/WiFiRequestKit/Tests/`, use [Swift Testing](https://developer.apple.com/documentation/testing). Press `Cmd+U` to run them, or run in Terminal, in the Kit's folder:

```bash
swift test
```

A new test target in the Kit runs with `Cmd+U` once it's added to the scheme: **Product ▸ Scheme ▸ Edit Scheme ▸ Test**.

## Using Swift packages

The firmware can use Swift packages that support Embedded Swift, such as [swift-mmio](https://github.com/apple/swift-mmio) for type-safe access to the chip's registers. Add them to `Firmware/Package.swift`, where the lines for swift-mmio show how: the package under `dependencies`, and its product under the `Firmware` target's dependencies. The next `Cmd+B` downloads and builds it, and code completion picks it up after that build. A package with macros, like swift-mmio, takes a few minutes to build the first time.

## When the firmware crashes

When the firmware crashes, for instance on an array index out of range or a `fatalError`, the board prints its registers and resets. Xcode's console (`Cmd+R`) and `espswift monitor` follow that with the backtrace, from the last build's symbols:

```
Backtrace (decoded by espswift):
  #0 Swift runtime failure: Index out of range at Firmware/Firmware.swift:6
  #1 specialized Array._checkSubscript(_:wasNativeTypeChecked:)
  #2 specialized Array.subscript.getter
  #3 element(_:at:) at Firmware/Firmware.swift:5
  #4 compute(_:) at Firmware/Firmware.swift:11
  #5 app_main() at Firmware/Firmware.swift:18
```

A crash at startup repeats after every reset; its backtrace is shown once. Embedded Swift leaves out `fatalError`'s message, so the backtrace says "fatal error" instead.

## Debugging on the board

You can stop the firmware at breakpoints in your Swift code and look at the backtrace and variables, with the LLDB debugger in Terminal. (Xcode's own debugger can't connect to the board.)

1. Connect the board through its **native USB port**: on the ESP32-C6-DevKitC-1, the port labelled **USB**, not **UART**. Debugging uses the chip's built-in USB-JTAG; flashing and the serial output work through this port too. (The ESP32-C2 has no built-in USB-JTAG and needs an external JTAG adapter.)
2. Press `Cmd+R` in Xcode to build the project and flash it.
3. In Terminal, run:

   ```bash
   ~/.espswift/bin/espswift debug
   ```

   It connects to the board, lets the firmware start, and pauses it at the `(lldb)` prompt. For example:

   ```
   b Firmware.swift:49  set a breakpoint on line 49 of Firmware.swift
   c                    continue until a breakpoint
   bt                   show the backtrace
   v                    show the variables
   n / s                next line / step into
   quit                 stop debugging; the firmware continues
   ```

Up to 4 breakpoints can be set at once (they're hardware breakpoints, as the code runs from flash). Many variables show as "optimized out", because the firmware is optimized for size.

## Opening Terminal in the source folder

Some tasks below need Terminal. `espswift` finds the project from any of its folders, such as the one with the `.xcodeproj`.

In Xcode's Project navigator, Control-click the `WiFiRequest` folder and choose **Open Terminal at Location**.

## Adding an ESP-IDF library

ESP-IDF libraries (components, written in C) come from the [ESP-IDF Component Registry](https://components.espressif.com). Each library page shows its name, such as `espressif/button`.

In Terminal, in the project's folder, run:

```bash
~/.espswift/bin/espswift add espressif/button --header iot_button.h
```

The first argument is the library's name. `--header` is the C header to include; check the library's documentation for it. If you leave it out, espswift guesses it from the name (`button.h` here).

It adds the library to `main/idf_component.yml` and the header to `Firmware/ESPIDF/include/ESPIDF.h`. Press `Cmd+B` to download and build it, and then use its functions from Swift.

To remove a library, delete its line from `main/idf_component.yml` and its `#include` from `ESPIDF.h`.

## Changing ESP-IDF settings

ESP-IDF settings, such as the CPU frequency, logging level or Wi-Fi options, live in `sdkconfig`. To change them with ESP-IDF's settings menu, run in Terminal, in the project's folder:

```bash
~/.espswift/bin/espswift settings
```

Use the arrow keys and Return to navigate, and press `S` to save and `Q` to quit. Then press `Cmd+B` in Xcode.

To keep a setting even if `sdkconfig` is deleted, also add it to `sdkconfig.defaults`.

## Changing the chip

The chip you chose when creating the project is set in `sdkconfig.defaults`:

```
CONFIG_IDF_TARGET="esp32c6"
```

The chip, and the flash size below it, are those of the board you chose when you created the project (ESP32-C6-DevKitC-1). To build for another RISC-V based ESP32 (`esp32c2`, `esp32c3`, `esp32c5`, `esp32c6`, `esp32c61`, `esp32h2` or `esp32p4`), change this line and press `Cmd+B`. The build then reconfigures the project for the new chip, which recreates `sdkconfig` from `sdkconfig.defaults` (the previous one is kept as `sdkconfig.old`).

The example blinks the board's LED: an addressable RGB LED (WS2812), separate red, green and blue LEDs, or a one-colour LED. A board without an LED only prints the colours. The board's LED, its pins and polarity are set in `Firmware/Board.swift`, e.g. `.addressable(pin: 8)` or `.single(pin: 15, activeLow: true)`; change it there for another board. `Firmware/LED.swift` drives it with ESP-IDF's GPIO and led_strip drivers.

Swift code can check ESP-IDF's settings and the chip's features with `#if`, as C code does: each setting that's on in `sdkconfig` is a compilation condition, such as `CONFIG_SOC_RMT_SUPPORTED` or `CONFIG_IDF_TARGET_ESP32C6`. `LED.swift` uses it to pick the RMT or the SPI peripheral for the LED.

## Building, flashing and watching in Terminal

`Cmd+B` and `Cmd+R` run `espswift`, ESPSwift's command-line tool, which you can also use in Terminal, in any folder of the project:

```bash
~/.espswift/bin/espswift build      # build (Cmd+B)
~/.espswift/bin/espswift run        # build, flash and show the serial output (Cmd+R)
~/.espswift/bin/espswift flash      # flash the latest build
~/.espswift/bin/espswift monitor    # show the serial output
~/.espswift/bin/espswift ports      # list the connected boards
```

Press `Ctrl+C` to stop the serial output. With several boards connected, choose one with `--port`, e.g. `--port /dev/cu.usbmodem1101`. `espswift monitor --idf` runs ESP-IDF's own monitor instead, which also sends what you type to the board.

The serial output starts when the monitor connects, just after the board starts, so the very first lines can be missing; press the board's RESET button to see them.

## More help

See the [ESPSwift](https://github.com/johankool/espswift) README for troubleshooting.
