import Testing
@testable import ConePlayer

@Suite("Volume control scale")
struct VolumeScaleTests {
    // The Figma component's 0–100% fill widths (out of its 100% width, 63 pt) now span
    // the whole control.
    @Test(arguments: [(0.0, 0.0), (10, 7), (50, 33), (90, 58), (100, 63)])
    func followsFigmaStates(_ volume: Double, _ width: Double) {
        #expect(abs(VolumeScale.fraction(for: volume) * 63 - width) < 0.01)
    }

    @Test func fullVolumeFillsTheControl() {
        #expect(VolumeScale.fraction(for: 100) == 1)
        #expect(VolumeScale.fraction(for: 150) == 1)
        #expect(VolumeScale.fraction(for: -5) == 0)
    }

    @Test(arguments: [5.0, 37, 64, 100])
    func inverseRoundTrips(_ volume: Double) {
        #expect(abs(VolumeScale.volume(for: VolumeScale.fraction(for: volume)) - volume) < 0.01)
    }
}

@MainActor
@Suite("Mac volume")
struct SystemVolumeTests {
    /// Reads only: tests never change the Mac's volume.
    @Test func readsTheOutputLevel() {
        let volume = SystemVolume()
        #expect((0...1).contains(volume.level))
    }
}
