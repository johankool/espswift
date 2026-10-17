/// Where ESPSwift keeps its installation, and where it finds ESP-IDF and the
/// Swift toolchain.
public struct Locations: Sendable {
    /// ESPSwift's own folder, ~/.espswift.
    public var espswiftHome: String
    /// ESP-IDF: IDF_PATH if it's set, else the pinned version EIM installed
    /// (by default in ~/.espressif/v6.1/esp-idf).
    public var idfPath: String
    /// ESP-IDF's tools and Python environments: ~/.espressif/tools (EIM's),
    /// or IDF_TOOLS_PATH if it's set.
    public var idfToolsPath: String
    /// The python3 with the pinned version, which ESP-IDF's environment is
    /// made for.
    public var python: String
    /// Where projects (and the Run scheme) find espswift; setup links it.
    public var command: String { "\(espswiftHome)/bin/espswift" }
    /// The file that records the path of the Swift toolchain setup installed.
    public var swiftToolchainRecord: String
    /// The Xcode template, on macOS.
    public var xcodeTemplate: String?

    public init(system: System) {
        let home = system.homeDirectory
        espswiftHome = "\(home)/.espswift"
        let idf = Pins.espIDF.components
        idfPath = system.environment["IDF_PATH"] ?? EIM(system: system).pinnedInstallation()?.path
            ?? "\(home)/.espressif/v\(idf[0]).\(idf[1])/esp-idf"
        idfToolsPath = system.environment["IDF_TOOLS_PATH"] ?? "\(home)/.espressif/tools"
        python = "\(espswiftHome)/python/bin/python3"
        swiftToolchainRecord = "\(espswiftHome)/swift-toolchain"
        xcodeTemplate = system.operatingSystem == .macOS
            ? "\(home)/Library/Developer/Xcode/Templates/Project Templates/Other/ESP32 RISC-V.xctemplate"
            : nil
    }

    /// The path, with the home folder written as ~, for messages.
    public func display(_ path: String, home: String) -> String {
        path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
