import AVFoundation
import CoreAudio

final class MicCamSignal {
    func anyInUse() -> Bool {
        let audioInUse = AVCaptureDevice.devices(for: .audio).contains { $0.isInUseByAnotherApplication }
        let videoInUse = AVCaptureDevice.devices(for: .video).contains { $0.isInUseByAnotherApplication }
        return audioInUse || videoInUse || defaultInputIsRunning()
    }

    private func defaultInputIsRunning() -> Bool {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr, dev != 0 else { return false }

        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}
