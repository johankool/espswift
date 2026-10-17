# Top-level CMakeLists.txt for an ESP-IDF + Embedded Swift project.
# The following boilerplate must be in this exact order for CMake to work.
cmake_minimum_required(VERSION 3.16)

# The Swift toolchain that builds the project's Swift package (see
# main/CMakeLists.txt). build.sh normally sets CMAKE_Swift_COMPILER; the
# fallback covers running idf.py directly: the toolchain install.sh
# recorded in ~/.espswift/swift-toolchain.
if(DEFINED ENV{CMAKE_Swift_COMPILER})
    get_filename_component(ESPSWIFT_SWIFT_BIN_DIR "$ENV{CMAKE_Swift_COMPILER}" DIRECTORY)
elseif(EXISTS "$ENV{HOME}/.espswift/swift-toolchain")
    file(STRINGS "$ENV{HOME}/.espswift/swift-toolchain" _swift_toolchain LIMIT_COUNT 1)
    set(ESPSWIFT_SWIFT_BIN_DIR "${_swift_toolchain}/usr/bin")
else()
    message(FATAL_ERROR "No Swift toolchain found for Embedded Swift. Please run install.sh first.")
endif()

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(DeepSleep)
