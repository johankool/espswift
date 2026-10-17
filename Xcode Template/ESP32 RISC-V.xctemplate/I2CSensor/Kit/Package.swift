// swift-tools-version: 6.0

// Plain Swift code, without ESP-IDF, and its tests. The firmware uses it
// (see Firmware/Package.swift), and as a package of the Xcode project its
// tests run on the Mac: press Cmd+U, or run `swift test` in this folder.
//
// Code here must work in Embedded Swift too, as it's built into the
// firmware.

import PackageDescription

let package = Package(
    name: "___PROJECTNAME___Kit",
    products: [
        .library(name: "SHT4x", targets: ["SHT4x"]),
    ],
    targets: [
        .target(name: "SHT4x"),
        .testTarget(name: "SHT4xTests", dependencies: ["SHT4x"]),
    ]
)
