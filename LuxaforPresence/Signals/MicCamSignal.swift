import AVFoundation
import CoreAudio
import Foundation
import OSLog

final class MicCamSignal: MicCamSignalProtocol {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "MicCamSignal")

    func requestAccessIfNeeded() {
        requestAccess(for: .audio)
        requestAccess(for: .video)
    }

    func anyInUse() -> Bool {
        let audioDevices = captureDevices(for: .audio)
        let videoDevices = captureDevices(for: .video)
        let audioInUse = audioDevices.contains { $0.isInUseByAnotherApplication }
        let videoInUse = videoDevices.contains { $0.isInUseByAnotherApplication }
        let coreAudio = coreAudioSnapshot()

        audioDevices.forEach { device in
            logger.debug("Audio device \(device.localizedName, privacy: .public) busy? \(device.isInUseByAnotherApplication)")
        }
        videoDevices.forEach { device in
            logger.debug("Video device \(device.localizedName, privacy: .public) busy? \(device.isInUseByAnotherApplication)")
        }

        if let defaultName = coreAudio.defaultDeviceName, let defaultID = coreAudio.defaultDeviceID {
            logger.debug("HAL default input \(defaultName, privacy: .public) [\(defaultID)] running? \(coreAudio.defaultRunning)")
        } else {
            logger.debug("HAL default input unavailable or not set")
        }
        coreAudio.statuses.forEach { status in
            guard status.hasInput else { return }
            logger.debug(
                "HAL device \(status.name, privacy: .public) [\(status.id)] input? \(status.hasInput) running? \(status.isRunning)"
            )
        }

        let halRunning = coreAudio.statuses.contains { $0.hasInput && $0.isRunning }
        return audioInUse || videoInUse || halRunning
    }

    private func coreAudioSnapshot() -> CoreAudioSnapshot {
        let statuses = audioDeviceStatuses()
        let defaultID = defaultInputDeviceID()
        let defaultStatus = statuses.first { $0.id == defaultID }
        return CoreAudioSnapshot(
            defaultDeviceID: defaultID,
            defaultDeviceName: defaultStatus?.name,
            defaultRunning: defaultStatus?.isRunning ?? false,
            statuses: statuses
        )
    }

    private func captureDevices(for mediaType: AVMediaType) -> [AVCaptureDevice] {
        if #available(macOS 10.15, *) {
            return AVCaptureDevice.DiscoverySession(
                deviceTypes: discoveryDeviceTypes(for: mediaType),
                mediaType: mediaType,
                position: .unspecified
            ).devices
        } else {
            return AVCaptureDevice.devices(for: mediaType)
        }
    }

    @available(macOS 10.15, *)
    private func discoveryDeviceTypes(for mediaType: AVMediaType) -> [AVCaptureDevice.DeviceType] {
        switch mediaType {
        case .audio:
            return [.builtInMicrophone, .externalUnknown]
        case .video:
            if #available(macOS 14.0, *), continuityCameraAllowed() {
                return [.builtInWideAngleCamera, .continuityCamera, .externalUnknown]
            } else {
                return [.builtInWideAngleCamera, .externalUnknown]
            }
        default:
            return [.externalUnknown]
        }
    }

    private func continuityCameraAllowed() -> Bool {
        (Bundle.main.object(forInfoDictionaryKey: "NSCameraUseContinuityCameraDeviceType") as? Bool) == true
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
              dev != 0 else { return nil }
        return dev
    }

    private func audioDeviceStatuses() -> [CoreAudioDeviceStatus] {
        return allAudioDeviceIDs().map { id in
            CoreAudioDeviceStatus(
                id: id,
                name: audioDeviceName(id) ?? "Unknown",
                isRunning: audioDeviceIsRunning(id),
                hasInput: audioDeviceHasInputScope(id)
            )
        }
    }

    private func allAudioDeviceIDs() -> [AudioDeviceID] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize) == noErr else {
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }
        return deviceIDs
    }

    private func audioDeviceName(_ id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr else { return nil }
        return name as String
    }

    private func audioDeviceIsRunning(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    private func audioDeviceHasInputScope(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return false
        }
        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &dataSize, rawPointer) == noErr else { return false }
        let bufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
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

private struct CoreAudioDeviceStatus {
    let id: AudioDeviceID
    let name: String
    let isRunning: Bool
    let hasInput: Bool
}

private struct CoreAudioSnapshot {
    let defaultDeviceID: AudioDeviceID?
    let defaultDeviceName: String?
    let defaultRunning: Bool
    let statuses: [CoreAudioDeviceStatus]
}
