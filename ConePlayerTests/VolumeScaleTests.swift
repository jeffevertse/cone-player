import Testing
@testable import ConePlayer

@Suite("Volume control scale")
struct VolumeScaleTests {
    // Fill widths of the Figma component's states, out of 88 pt.
    @Test(arguments: [(0.0, 0.0), (10, 7), (50, 33), (100, 63), (150, 75), (200, 88)])
    func matchesFigmaStates(_ volume: Double, _ width: Double) {
        #expect(abs(VolumeScale.fraction(for: volume) * 88 - width) < 0.01)
    }

    @Test func clampsOutsideRange() {
        #expect(VolumeScale.fraction(for: -20) == 0)
        #expect(VolumeScale.fraction(for: 300) == 1)
    }

    @Test(arguments: [5.0, 37, 100, 123, 180])
    func inverseRoundTrips(_ volume: Double) {
        #expect(abs(VolumeScale.volume(for: VolumeScale.fraction(for: volume)) - volume) < 0.01)
    }
}
