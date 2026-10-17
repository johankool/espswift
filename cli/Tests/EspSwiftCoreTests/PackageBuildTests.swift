@testable import EspSwiftCore
import Foundation
import Testing

@Suite struct PackageBuildTests {
    @Test func splitsShellWords() {
        #expect(ShellWords.split(#"-DIDF_VER=\"v6.1\" "-specs=/a b/picolibc.specs" -I/x 'it''s'"#)
                == [#"-DIDF_VER="v6.1""#, "-specs=/a b/picolibc.specs", "-I/x", "its"])
        #expect(ShellWords.split("  -march=rv32imac\n\"-mabi=ilp32\"\n") == ["-march=rv32imac", "-mabi=ilp32"])
    }

    @Test func takesESPIDFsFlags() throws {
        let system = FakeSystem()
        system.file("/b/compile_commands.json", """
            [{"directory": "/b", "file": "/p/P/main/swift_flags.c",
              "command": "riscv32-esp-elf-gcc @/b/toolchain/cflags -DESP_PLATFORM -I/idf/include -Wall -c /p/P/main/swift_flags.c"}]
            """)
        system.file("/b/toolchain/cflags", "-march=rv32imac_zicsr_zifencei_xesppie\n\"-specs=/b/picolibc.specs\"\n")
        let build = PackageBuild(system: system, buildFolder: "/b", flagsSource: "/p/P/main/swift_flags.c",
                                 projectFolder: "/p", packageFolder: "/p/Firmware", swiftBin: "/t/usr/bin",
                                 output: "/b/libFirmware.a", implicitIncludes: ["/gcc/include"])
        #expect(try build.cFlags() == [
            "-march=rv32imac_zicsr_zifencei", "-mabi=ilp32", "-fno-pic", "-fno-pie", "-ffunction-sections",
            "-DESP_PLATFORM", "-I/idf/include", "-isystem", "/gcc/include",
        ])
    }

    @Test func makesSdkconfigsSettingsSwiftConditions() throws {
        let system = FakeSystem()
        system.file("/b/config/sdkconfig.json", """
            {"IDF_TARGET": "esp32c6", "IDF_TARGET_ESP32C6": true, "SOC_RMT_SUPPORTED": true,
             "LOG_COLORS": false, "LOG_DEFAULT_LEVEL": 3}
            """)
        let build = PackageBuild(system: system, buildFolder: "/b", flagsSource: "", projectFolder: "/p",
                                 packageFolder: "/p/Firmware", swiftBin: "/t/usr/bin", output: "", implicitIncludes: [])
        #expect(try build.swiftConditions() == ["-D", "CONFIG_IDF_TARGET_ESP32C6", "-D", "CONFIG_SOC_RMT_SUPPORTED"])
    }

    @Test func worksOutsideThePackageFolderXcodeSyncs() {
        let system = FakeSystem()
        // Xcode's DerivedData; idf.py's ./build, inside the project.
        #expect(PackageBuild.scratchFolder(buildFolder: "/dd/esp-idf", projectFolder: "/p", system: system) == "/dd/esp-idf/swiftpm")
        #expect(PackageBuild.scratchFolder(buildFolder: "/p/P/build", projectFolder: "/p", system: system) == "/p/.build/esp-idf")
    }
}

@Suite struct CodeCompletionTests {
    @Test func takesTheFlagsSwiftNeedsFromSwiftPMsCommand() {
        let arguments = [
            "/t/usr/bin/swiftc", "-module-name", "Firmware", "-I", "/s/release/Modules",
            "-I", "/Applications/Xcode.app/Contents/Developer/usr/lib",
            "-Xcc", "-fmodule-map-file=/s/release/ESPIDF.build/module.modulemap",
            "-Xcc", "-I", "-Xcc", "/p/Firmware/ESPIDF/include",
            "-Xcc", "-I/idf/include", "-Xcc", "-I/idf/include",
            "-Xcc", "-isystem", "-Xcc", "/gcc/include",
            "-Xcc", "-DESP_PLATFORM", "-Xcc", "--sysroot", "-Xcc", "/Applications/Xcode.app/x.sdk",
            "-D", "CONFIG_SOC_RMT_SUPPORTED", "-DSWIFT_PACKAGE",
            "-Xfrontend", "-load-plugin-executable", "-Xfrontend", "/s/MMIOMacros-tool#MMIOMacros",
            "-plugin-path", "/t/usr/lib/swift/host/plugins/testing",
        ]
        let flags = CodeCompletion.flags(fromSwiftPMArguments: arguments)
        #expect(flags == [
            "-I/s/release/Modules", "-Xcc", "-fmodule-map-file=/s/release/ESPIDF.build/module.modulemap",
            "-I/p/Firmware/ESPIDF/include", "-I/idf/include", "-I/idf/include", "-Xcc", "-isystem/gcc/include",
            "-Xcc", "-DESP_PLATFORM", "-DCONFIG_SOC_RMT_SUPPORTED", "-DSWIFT_PACKAGE",
            "-load-plugin-executable", "/s/MMIOMacros-tool#MMIOMacros",
        ])
        // Each include path once, quoted.
        #expect(CodeCompletion.responseFileText(["-I/a b", "-I/a b", "-Xcc", "-DX=\"1\""])
                == "\"-I/a b\"\n\"-Xcc\"\n\"-DX=\\\"1\\\"\"\n")
    }
}
