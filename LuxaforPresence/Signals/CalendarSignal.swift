import EventKit
import OSLog

final class CalendarSignal {
    private lazy var store = EKEventStore()
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "CalendarSignal")

    // Call once at startup if using calendar
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestAccess(to: .event) { granted, error in
            if let error { self.logger.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)") }
            self.logger.log("Calendar access granted? \(granted)")
            completion(granted)
        }
    }

    func hasOngoingMeetingEvent() -> Bool {
        // if you didn’t get permission, bail out:
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized else {
            logger.debug("Calendar authorization status \(status.rawValue) not authorized")
            return false
        }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-300),
                                            end: now.addingTimeInterval(3*3600),
                                            calendars: nil)
        let events = store.events(matching: pred).filter { $0.startDate <= now && now <= $0.endDate }
        logger.debug("Found \(events.count) concurrent calendar events")
        let hasMeeting = events.contains { ev in
            let blob = [ev.location, ev.notes, ev.url?.absoluteString].compactMap { $0 }.joined(separator: " ")
            return blob.range(of: #"(?i)(zoom\.us|teams\.microsoft\.com|meet\.google\.com|webex\.com)"#, options: .regularExpression) != nil
        }
        logger.debug("Meeting URL present? \(hasMeeting)")
        return hasMeeting
    }
}
