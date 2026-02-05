import AVFoundation
import Foundation
import OSLog

protocol VoiceActivitySignalProtocol {
    func requestAccessIfNeeded()
    func isVoiceActive() -> Bool
    var lastVoiceActivityDate: Date? { get }
}

final class VoiceActivitySignal: VoiceActivitySignalProtocol {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "VoiceActivitySignal")
    private let engine = AVAudioEngine()
    private let threshold: Double
    private let stateLock = NSLock()
    private var voiceActive = false
    private var lastActivity: Date?
    private var started = false

    init(threshold: Double = 0.02) {
        self.threshold = threshold
    }

    var lastVoiceActivityDate: Date? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return lastActivity
    }

    func isVoiceActive() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return voiceActive
    }

    func requestAccessIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            startIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    self?.logger.log("Microphone access granted for VAD")
                    self?.startIfNeeded()
                } else {
                    self?.logger.error("Microphone access denied; VAD disabled")
                }
            }
        case .denied, .restricted:
            logger.error("Microphone access denied or restricted; VAD disabled")
        @unknown default:
            logger.error("Unknown microphone authorization status \(status.rawValue, privacy: .public)")
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        do {
            try engine.start()
            logger.log("Voice activity engine started")
        } catch {
            logger.error("Failed to start VAD engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0, channelCount > 0 else { return }

        var totalEnergy: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            var sum: Float = 0
            var index = 0
            while index < frameLength {
                let value = samples[index]
                sum += value * value
                index += 1
            }
            totalEnergy += sum
        }

        let meanEnergy = totalEnergy / Float(frameLength * channelCount)
        let rms = sqrt(meanEnergy)
        let isActive = Double(rms) >= threshold
        let now = Date()

        stateLock.lock()
        voiceActive = isActive
        if isActive {
            lastActivity = now
        }
        stateLock.unlock()
    }
}
