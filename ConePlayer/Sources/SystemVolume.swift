import AudioToolbox
import CoreAudio
import Foundation
import Observation

/// The Mac's output volume and mute, read and set with CoreAudio and kept live with
/// property listeners. The keyboard's volume keys change these, so following them keeps
/// Cone Player's volume control in step with the keys and Control Center.
@MainActor
@Observable
final class SystemVolume {
    /// 0…1.
    private(set) var level: Double = 0
    private(set) var isMuted = false
    /// False for outputs whose volume can't be changed from the Mac (HDMI, some USB DACs).
    private(set) var canSetVolume = false
    private(set) var canMute = false

    @ObservationIgnored private var device = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    /// The level before muting, for outputs without a mute switch.
    @ObservationIgnored private var levelBeforeMute: Double?

    init() {
        var address = Self.defaultOutputAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.bindDefaultDevice() }
        }
        bindDefaultDevice()
    }

    // MARK: - Changing

    func setLevel(_ newLevel: Double) {
        guard canSetVolume else { return }
        var value = Float32(min(max(newLevel, 0), 1))
        var address = Self.volumeAddress
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if newLevel > 0 && isMuted { setMuted(false) }
        refresh()
    }

    func setMuted(_ muted: Bool) {
        if canMute {
            var value = UInt32(muted ? 1 : 0)
            var address = Self.muteAddress
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        } else if muted {
            levelBeforeMute = level
            setLevel(0)
        } else {
            setLevel(levelBeforeMute ?? 0.5)
            levelBeforeMute = nil
        }
        refresh()
    }

    // MARK: - Reading

    private func bindDefaultDevice() {
        for (address, block) in deviceListeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(device, &address, .main, block)
        }
        deviceListeners = []

        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = Self.defaultOutputAddress
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        device = id

        canSetVolume = isSettable(Self.volumeAddress)
        canMute = isSettable(Self.muteAddress)
        for address in [Self.volumeAddress, Self.muteAddress] {
            var address = address
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            if AudioObjectAddPropertyListenerBlock(device, &address, .main, block) == noErr {
                deviceListeners.append((address, block))
            }
        }
        refresh()
    }

    private func refresh() {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.volumeAddress
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr {
            level = Double(volume)
        }
        var muted = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address = Self.muteAddress
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr {
            isMuted = muted != 0
        } else {
            isMuted = level == 0
        }
    }

    private func isSettable(_ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    // MARK: - Addresses

    private static let defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    /// The "virtual main volume" is what the volume keys and the menu bar slider change.
    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
}
