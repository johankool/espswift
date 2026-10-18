// Tests for the LightColor target, run on the Mac: press Cmd+U in Xcode, or
// run `swift test` in the package folder.

import LightColor
import Testing

@Test func showsHuesAtFullBrightness() {
    var light = LightState()
    light.mode = .hueSaturation
    light.level = 254
    light.saturation = 254
    light.hue = 0
    #expect(light.rgb == (255, 0, 0))
    light.hue = 85  // 120°
    #expect(light.rgb == (0, 255, 0))
    light.hue = 170  // 240°
    #expect(light.rgb == (0, 0, 255))
}

@Test func scalesToTheLevel() {
    var light = LightState()
    light.mode = .hueSaturation
    light.saturation = 254
    light.hue = 0
    light.level = 127
    #expect(light.rgb == (127, 0, 0))
}

@Test func showsWhiteWithoutSaturation() {
    var light = LightState()
    light.mode = .hueSaturation
    light.level = 254
    light.saturation = 0
    #expect(light.rgb == (255, 255, 255))
}

@Test func showsWarmAndCoolWhite() {
    var light = LightState()
    light.level = 254
    light.temperature = 370  // 2700 K
    #expect(light.rgb == (255, 169, 87))
    light.temperature = 153  // 6535 K
    #expect(light.rgb == (255, 249, 253))
}

@Test func isDarkWhenOff() {
    var light = LightState()
    light.isOn = false
    #expect(light.rgb == (0, 0, 0))
}
