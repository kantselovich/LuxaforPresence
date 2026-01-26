import Foundation

protocol MicCamSignalProtocol {
    func requestAccessIfNeeded()
    func isMicrophoneInUse() -> Bool
    func isCameraInUse() -> Bool
    func anyInUse() -> Bool
}

protocol FrontmostAppSignalProtocol {
    func isFrontmostIn(allowlist: Set<String>) -> Bool
}

protocol CalendarSignalProtocol {
    func requestAccess(completion: @escaping (Bool) -> Void)
    func hasOngoingMeetingEvent() -> Bool
}

protocol MeetingDetectorProtocol {
    var name: String { get }
    func isMeetingActive() -> Bool
}
