import Foundation

protocol MicCamSignalProtocol {
    func requestAccessIfNeeded()
    func anyInUse() -> Bool
}

protocol FrontmostAppSignalProtocol {
    func isFrontmostIn(allowlist: Set<String>) -> Bool
}

protocol CalendarSignalProtocol {
    func requestAccess(completion: @escaping (Bool) -> Void)
    func hasOngoingMeetingEvent() -> Bool
}
