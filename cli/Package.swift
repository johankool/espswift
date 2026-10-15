// swift-tools-version: 6.0

// espswift: the command-line tool for Embedded Swift on RISC-V based ESP32
// chips. It sets up and checks ESP-IDF and the Swift toolchain, and builds,
// flashes and monitors projects, on macOS and Linux.

import PackageDescription

let package = Package(
    name: "espswift",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "espswift", targets: ["espswift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        // The command line: parses the arguments and prints the results.
        .executableTarget(
            name: "espswift",
            dependencies: [
                "EspSwiftCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        // What the commands do, testable without a terminal or a real system.
        .target(name: "EspSwiftCore", dependencies: ["CSerialPort"]),
        // Opening serial ports, which needs C (ioctl).
        .target(name: "CSerialPort"),
        .testTarget(name: "EspSwiftCoreTests", dependencies: ["EspSwiftCore"]),
    ]
)
