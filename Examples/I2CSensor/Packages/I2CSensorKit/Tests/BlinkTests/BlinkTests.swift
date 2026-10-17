// Tests for the Blink target, run on the Mac: press Cmd+U in Xcode, or run
// `swift test` in the package folder.

import Blink
import Testing

@Test func cyclesThroughRedGreenBlueAndOff() {
    let steps = (0..<4).map { blinkStep($0) }
    #expect(steps.map(\.red) == [32, 0, 0, 0])
    #expect(steps.map(\.green) == [0, 32, 0, 0])
    #expect(steps.map(\.blue) == [0, 0, 32, 0])
    #expect(steps.map { "\($0.name)" } == ["Red", "Green", "Blue", "Off"])
}

@Test(arguments: [0, 1, 2, 3] as [UInt32])
func repeatsEveryFourSteps(index: UInt32) {
    let step = blinkStep(index)
    let next = blinkStep(index + 4)
    #expect([step.red, step.green, step.blue] == [next.red, next.green, next.blue])
}

@Test func usesTheGivenBrightness() {
    #expect(blinkStep(0, brightness: 255).red == 255)
}
