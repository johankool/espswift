import Foundation

/// espswift's own version.
public let espswiftVersion = "0.2.2"

/// The versions ESPSwift is built and tested with: `espswift setup` installs
/// them, and `espswift doctor` checks for them. (Until `espswift setup`
/// replaces it, install.sh has the same pins.)
public enum Pins {
    /// ESP-IDF, the Espressif IoT Development Framework.
    public static let espIDF = Version(6, 1, 0)
    /// The Swift toolchain that's installed (on macOS; on Linux, swiftly
    /// installs the latest of the series). Xcode's own can't be used: it
    /// doesn't include Embedded Swift for RISC-V.
    public static let swift = Version(6, 4, 0)
    /// The Swift versions that work: any 6.4.x.
    public static let swiftSeries = Version(6, 4)
    /// The Python version on macOS. ESP-IDF finds its environment by the
    /// version of the first python3 on PATH, so Homebrew moving python3 to
    /// a newer release would break builds; ESPSwift uses this one instead.
    public static let python = Version(3, 14)
    /// The oldest Python ESP-IDF supports, for Linux, where ESPSwift uses
    /// the system's python3.
    public static let minimumPython = Version(3, 10)
    /// The chips the template offers: the RISC-V based ESP32s.
    public static let chips = ["esp32c2", "esp32c3", "esp32c5", "esp32c6", "esp32c61", "esp32h2", "esp32p4"]
}

/// A version number such as 6.4.0 or 3.14.
public struct Version: Equatable, Comparable, CustomStringConvertible, Sendable {
    public var components: [Int]

    public init(_ components: Int...) {
        self.components = components
    }

    /// Reads a version such as "6.4.0", "v6.1" or "3.14.8rc1" (the leading
    /// digits of each component count).
    public init?(_ string: String) {
        var text = Substring(string)
        if text.first == "v" { text = text.dropFirst() }
        var components: [Int] = []
        for part in text.split(separator: ".", omittingEmptySubsequences: false) {
            let digits = part.prefix(while: \.isNumber)
            guard let number = Int(digits) else { break }
            components.append(number)
            if digits.count != part.count { break }
        }
        guard !components.isEmpty else { return nil }
        self.components = components
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    /// Whether this version is the pinned one: equal in every component the
    /// pin has, counting missing components as 0. So Python 3.14.8 satisfies
    /// the pin 3.14, and Swift 6.4 (as swiftc reports 6.4.0) satisfies 6.4.0.
    public func satisfies(_ pin: Version) -> Bool {
        pin.components.indices.allSatisfy { index in
            component(index) == pin.components[index]
        }
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count where lhs.component(index) != rhs.component(index) {
            return lhs.component(index) < rhs.component(index)
        }
        return false
    }

    public static func == (lhs: Version, rhs: Version) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    private func component(_ index: Int) -> Int {
        index < components.count ? components[index] : 0
    }
}

/// Reads versions from the output of tools and from ESP-IDF's files.
public enum VersionParser {
    /// ESP-IDF's version, from tools/cmake/version.cmake:
    /// `set(IDF_VERSION_MAJOR 6)` and so on.
    public static func espIDF(versionCMake text: String) -> Version? {
        func value(_ name: String) -> Int? {
            for line in text.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let prefix = "set(\(name) "
                if trimmed.hasPrefix(prefix), trimmed.hasSuffix(")") {
                    return Int(trimmed.dropFirst(prefix.count).dropLast().trimmingCharacters(in: .whitespaces))
                }
            }
            return nil
        }
        guard let major = value("IDF_VERSION_MAJOR"), let minor = value("IDF_VERSION_MINOR") else { return nil }
        return Version(major, minor, value("IDF_VERSION_PATCH") ?? 0)
    }

    /// Swift's version, from `swiftc --version`: "Apple Swift version 6.4
    /// (swift-6.4-RELEASE)" on macOS, "Swift version 6.4 (...)" on Linux.
    public static func swift(versionOutput text: String) -> Version? {
        version(after: "Swift version ", in: text)
    }

    /// Python's version, from `python3 --version`: "Python 3.14.8".
    public static func python(versionOutput text: String) -> Version? {
        version(after: "Python ", in: text)
    }

    /// The first number of the text, for tools such as CMake ("cmake version
    /// 4.4.4") and Ninja ("1.13.2").
    public static func firstVersion(in text: String) -> Version? {
        for word in text.split(whereSeparator: { $0 == " " || $0 == "\n" }) {
            if word.first?.isNumber == true, let version = Version(String(word)) {
                return version
            }
        }
        return nil
    }

    private static func version(after marker: String, in text: String) -> Version? {
        guard let range = text.range(of: marker) else { return nil }
        let word = text[range.upperBound...].prefix(while: { !$0.isWhitespace })
        return Version(String(word))
    }
}
