@testable import EspSwiftCore
import Testing

@Suite struct BuildOutputFilterTests {
    let source = "/Users/test/Blink/Blink"

    func filter(_ lines: [String], files: [String: String] = [:]) -> (output: [String], errors: Int) {
        var filter = BuildOutputFilter(sourceFolder: source, readFile: { files[$0] })
        let output = lines.flatMap { filter.process($0) } + filter.finish()
        return (output, filter.errorCount)
    }

    @Test func passesCompilerErrorsOn() {
        let error = "/Users/test/Blink/Firmware/Firmware.swift:16:23: error: cannot convert value of type 'String' to specified type 'Int'"
        let result = filter([
            "[4/10] Building Swift Module '__idf_main' with 1 source",
            "FAILED: [code=1] esp-idf/main/libmain.a",
            "/Users/test/.swiftly/bin/swiftc -c -DESP_PLATFORM ...",
            error,
            "16 |     let broken: Int = \"not a number\"",
            "ninja: build stopped: subcommand failed.",
        ])
        #expect(result.output == [error, "16 |     let broken: Int = \"not a number\""])
        #expect(result.errors == 1)
    }

    @Test func locatesCMakeErrorsInTheProject() {
        let result = filter([
            "CMake Error at managed_components/espressif__idf_swift/CMakeLists.txt:147 (target_sources):",
            "  Cannot find source file:",
            "",
            "    REQUIRES",
            "Call Stack (most recent call first):",
            "  main/CMakeLists.txt:23 (idf_component_register_swift)",
            "",
            "-- Configuring incomplete, errors occurred!",
        ])
        #expect(result.output == ["\(source)/main/CMakeLists.txt:23: error: Cannot find source file: REQUIRES"])
        #expect(result.errors == 1)
    }

    @Test func dropsCMakeWarningsFromESPIDF() {
        let result = filter([
            "CMake Warning at /Users/test/.espswift/esp-idf/tools/cmake/component_validation.cmake:106 (message):",
            "  Private include directory belongs to component esp_wifi.",
            "Call Stack (most recent call first):",
            "  /Users/test/.espswift/esp-idf/CMakeLists.txt:356 (__component_validation_run_checks)",
            "",
        ])
        #expect(result.output.isEmpty)
    }

    @Test func turnsUnknownOptionsIntoWarningsOnTheirLine() {
        let defaults = "\(source)/sdkconfig.defaults"
        let result = filter(
            ["NOTE: unknown kconfig symbol 'NO_SUCH_OPTION' assigned to 'y' in \(defaults)"],
            files: [defaults: "CONFIG_IDF_TARGET=\"esp32c6\"\n\nCONFIG_NO_SUCH_OPTION=y\n"])
        #expect(result.output == [
            "\(defaults):3: warning: Unknown ESP-IDF option CONFIG_NO_SUCH_OPTION; it has no effect. Check its name with idf.py menuconfig.",
        ])
    }

    @Test func showsProgressPerTenthOfTheMainBuild() {
        let lines = (1...100).map { "[\($0)/100] Building C object esp-idf/x.c.obj" }
            + (1...60).map { "[\($0)/60] Bootloader step" }  // a smaller ninja build within it
        let output = filter(lines).output
        #expect(output.count == 11)
        #expect(output.first == "Building... 0% (1 of 100 steps)")
        #expect(output.last == "Building... 100% (100 of 100 steps)")
    }

    @Test func dropsNoiseAndKeepsTheFirmwareSize() {
        let size = "Blink.bin binary size 0x32270 bytes. Smallest app partition is 0x100000 bytes. 0xcdd90 bytes (80%) free."
        let result = filter([
            "-- Building ESP-IDF components for target esp32c6",
            "NOTE: Processing 3 dependencies:",
            "Partition table binary generated. Contents:",
            "*******************************************************************************",
            "nvs,data,nvs,0x9000,24K,",
            "*******************************************************************************",
            "Build of product 'Firmware' complete! (3.40s)",
            "esptool v5.6.0",
            size,
            "",
            "",
            "Project build complete. To flash, run:",
            " idf.py flash",
        ])
        #expect(result.output == [size, ""])
    }

    @Test func removesEscapeCodes() {
        let line = "\u{1B}[0;33mwarning\u{1B}[0m: name [#\u{1B}]8;;https://docs.swift.org\u{1B}\\NoUsage\u{1B}]8;;\u{1B}\\]\r"
        #expect(BuildOutputFilter.removingEscapeCodes(line) == "warning: name [#NoUsage]")
    }
}
