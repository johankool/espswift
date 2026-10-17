// swift-tools-version: 6.0

// The firmware's Swift code, as a Swift package: ESP-IDF builds it (with
// SwiftPM) into the firmware, see BLELight/main/CMakeLists.txt.
// Xcode doesn't build it; the Indexing target gives it code completion.

import PackageDescription

let package = Package(
    name: "Firmware",
    products: [
        // ESP-IDF links this library into the firmware.
        .library(name: "Firmware", type: .static, targets: ["Firmware"]),
    ],
    dependencies: [
        // Plain Swift code and its tests, testable on the Mac.
        .package(path: "../Packages/BLELightKit"),
        // Swift packages that support Embedded Swift, such as:
        // .package(url: "https://github.com/apple/swift-mmio.git", from: "0.1.1"),
    ],
    targets: [
        // The Swift files in this folder: app_main and the code that uses ESP-IDF.
        .target(
            name: "Firmware",
            dependencies: [
                "ESPIDF",
                .product(name: "Light", package: "BLELightKit"),
                // .product(name: "MMIO", package: "swift-mmio"),
            ],
            path: ".",
            exclude: ["ESPIDF"]
        ),
        // ESP-IDF's C APIs, for `import ESPIDF` (see ESPIDF/include/ESPIDF.h).
        .target(name: "ESPIDF", path: "ESPIDF"),
    ]
)
