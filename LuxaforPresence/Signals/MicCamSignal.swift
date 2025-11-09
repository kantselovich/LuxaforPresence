import AVFoundation
import CoreAudio
import OSLog

final class MicCamSignal {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "MicCamSignal")

    func requestAccessIfNeeded() {
        requestAccess(for: .audio)
        requestAccess(for: .video)
    }

    func anyInUse() -> Bool {
        let audioDevices = AVCaptureDevice.devices(for: .audio)
        let videoDevices = AVCaptureDevice.devices(for: .video)
        let audioInUse = audioDevices.contains { $0.isInUseByAnotherApplication }
        let videoInUse = videoDevices.contains { $0.isInUseByAnotherApplication }
        let halRunning = defaultInputIsRunning()
        logger.debug("Audio devices \(audioDevices.map { $0.localizedName }, privacy: .public) in use? \(audioInUse)")
        logger.debug("Video devices \(videoDevices.map { $0.localizedName }, privacy: .public) in use? \(videoInUse)")
        logger.debug("HAL default input running? \(halRunning)")
        return audioInUse || videoInUse || halRunning
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

    private func requestAccess(for mediaType: AVMediaType) {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch status {
        case .authorized:
            logger.debug("\(mediaType.rawValue, privacy: .public) access already authorized")
        case .notDetermined:
            logger.log("Requesting \(mediaType.rawValue, privacy: .public) access for mic/cam detection")
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                if granted {
                    self.logger.log("\(mediaType.rawValue, privacy: .public) access granted for mic/cam detection")
                } else {
                    self.logger.error("\(mediaType.rawValue, privacy: .public) access denied; mic/cam signal limited")
                }
            }
        case .denied, .restricted:
            logger.error("\(mediaType.rawValue, privacy: .public) access denied or restricted; mic/cam signal limited")
        @unknown default:
            logger.error("Unknown authorization status \(status.rawValue, privacy: .public) for \(mediaType.rawValue, privacy: .public)")
        }
    }
}
