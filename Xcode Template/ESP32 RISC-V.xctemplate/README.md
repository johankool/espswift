# ___PROJECTNAME___

Embedded Swift firmware for ___VARIABLE_boardName___ (`___VARIABLE_chip___`), built with ESP-IDF.

## Everyday use in Xcode

| Shortcut | What it does |
| --- | --- |
| `Cmd+B` | Builds the firmware |
| `Cmd+R` | Builds, flashes the firmware to the connected board, and shows its serial output in Xcode's console |
| `Cmd+Shift+K` | Cleans the build |

**Product ▸ Perform Action ▸ Run Without Building** flashes whatever was built last, even if that was another project.

Errors and warnings from the build, in Swift, C, `CMakeLists.txt` and `sdkconfig.defaults`, appear in the Issue navigator (`Cmd+5`); click one to jump to its line. The build log shows only those and the firmware size; ESP-IDF's full output is in the build folder, in `log/build-output.log` (the build log names it when a build fails). To see all of it in the build log, add a user-defined build setting `ESPSWIFT_VERBOSE` = `1` to the ___PROJECTNAME___ target.

## What's in this project

Your Swift code is in two Swift packages:

- **Firmware**: the firmware itself, `app_main` and the code that uses ESP-IDF. ESP-IDF builds it (with the Swift Package Manager) into the firmware. Xcode gives it code completion for ESP-IDF's C APIs (see below).
- **___PROJECTNAME___Kit**, in `Packages/`: plain Swift code that doesn't use ESP-IDF, such as the blink pattern in `Blink`, and its tests. The firmware uses it, and Xcode builds and tests it on the Mac (`Cmd+U`).

```
___PROJECTNAME___/
├── README.md                   # This file
├── ___PROJECTNAME___.xcodeproj
├── Firmware/
│   ├── Firmware.swift          # Your firmware code starts here (app_main)
│   ├── Package.swift           # The firmware's packages, such as swift-mmio
│   └── ESPIDF/include/
│       └── ESPIDF.h            # ESP-IDF's C APIs for Swift: `import ESPIDF`
├── Packages/
│   └── ___PROJECTNAME___Kit/    # Plain Swift code, tested on the Mac
│       ├── Package.swift
│       ├── Sources/Blink/      # The blink pattern
│       └── Tests/BlinkTests/   # Its tests: Cmd+U
└── ___PROJECTNAME___/           # The ESP-IDF project (the "source folder")
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

Code in the Kit package can be tested on the Mac, without a board. Its tests, in `Packages/___PROJECTNAME___Kit/Tests/`, use [Swift Testing](https://developer.apple.com/documentation/testing). Press `Cmd+U` to run them, or run in Terminal, in the Kit's folder:

```bash
swift test
```

A new test target in the Kit runs with `Cmd+U` once it's added to the scheme: **Product ▸ Scheme ▸ Edit Scheme ▸ Test**.

## Using Swift packages

The firmware can use Swift packages that support Embedded Swift, such as [swift-mmio](https://github.com/apple/swift-mmio) for type-safe access to the chip's registers. Add them to `Firmware/Package.swift`, where the lines for swift-mmio show how: the package under `dependencies`, and its product under the `Firmware` target's dependencies. The next `Cmd+B` downloads and builds it, and code completion picks it up after that build. A package with macros, like swift-mmio, takes a few minutes to build the first time.

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

In Xcode's Project navigator, Control-click the `___PROJECTNAME___` folder and choose **Open Terminal at Location**.

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
CONFIG_IDF_TARGET="___VARIABLE_chip___"
```

The chip, and the flash size below it, are those of the board you chose when you created the project (___VARIABLE_boardName___). To build for another RISC-V based ESP32 (`esp32c2`, `esp32c3`, `esp32c5`, `esp32c6`, `esp32c61`, `esp32h2` or `esp32p4`), change this line and press `Cmd+B`. The build then reconfigures the project for the new chip, which recreates `sdkconfig` from `sdkconfig.defaults` (the previous one is kept as `sdkconfig.old`).

The example blinks the board's LED: an addressable RGB LED (WS2812), separate red, green and blue LEDs, or a one-colour LED. A board without an LED only prints the colours. The board's LED, its pins and polarity are set in `Firmware/ESPIDF/include/ESPIDF.h` (`BOARD_LED_…`); change them there for another board.

## Building, flashing and watching in Terminal

`Cmd+B` and `Cmd+R` run `espswift`, ESPSwift's command-line tool, which you can also use in Terminal, in any folder of the project:

```bash
~/.espswift/bin/espswift build      # build (Cmd+B)
~/.espswift/bin/espswift run        # build, flash and show the serial output (Cmd+R)
~/.espswift/bin/espswift flash      # flash the latest build
~/.espswift/bin/espswift monitor    # show the serial output
~/.espswift/bin/espswift ports      # list the connected boards
```

Press `Ctrl+C` to stop the serial output. With several boards connected, choose one with `--port`, e.g. `--port /dev/cu.usbmodem1101`. `espswift monitor --idf` runs ESP-IDF's own monitor instead, which decodes crash backtraces into file and line numbers and sends what you type to the board.

The serial output starts when the monitor connects, just after the board starts, so the very first lines can be missing; press the board's RESET button to see them.

## More help

See the [Embedded Swift Xcode Template](https://github.com/letstakeabreak/Embedded-Swift-Xcode-Template) README for troubleshooting.
