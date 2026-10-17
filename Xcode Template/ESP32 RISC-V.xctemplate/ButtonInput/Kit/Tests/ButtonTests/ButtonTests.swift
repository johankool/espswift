// Tests for the Button target, run on the Mac: press Cmd+U in Xcode, or run
// `swift test` in the package folder.

import Button
import Testing

/// The events for a sequence of readings, as strings ("-" for none).
func events(_ readings: String, debouncer: ButtonDebouncer = ButtonDebouncer()) -> [String] {
    var debouncer = debouncer
    return readings.map { reading in
        switch debouncer.update(isDown: reading == "#") {
        case nil: "-"
        case .pressed: "pressed"
        case .released(let heldFor): "released after \(heldFor)"
        case .longPressed: "long"
        }
    }.filter { $0 != "-" }
}

@Test func reportsAPressOnceItIsStable() {
    #expect(events("..###") == ["pressed"])
    #expect(events("..##") == [])
}

@Test func ignoresBounce() {
    #expect(events("..#.#.##.#.....") == [])
    #expect(events("..#.###.#.###......") == ["pressed", "released after 9"])
}

@Test func reportsTheRelease() {
    #expect(events("###.....") == ["pressed", "released after 3"])
}

@Test func reportsALongPressOnce() {
    let debouncer = ButtonDebouncer(stableReadings: 1, longPressReadings: 5)
    #expect(events("#########...", debouncer: debouncer) == ["pressed", "long", "released after 9"])
}
