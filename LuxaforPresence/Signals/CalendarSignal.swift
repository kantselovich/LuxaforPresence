import EventKit

final class CalendarSignal {
    private lazy var store = EKEventStore()

    // Call once at startup if using calendar
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestAccess(to: .event) { granted, _ in completion(granted) }
    }

    func hasOngoingMeetingEvent() -> Bool {
        // if you didn’t get permission, bail out:
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { return false }
        let now = Date()
        let pred = store.predicateForEvents(withStart: now.addingTimeInterval(-300),
                                            end: now.addingTimeInterval(3*3600),
                                            calendars: nil)
        let events = store.events(matching: pred).filter { $0.startDate <= now && now <= $0.endDate }
        return events.contains { ev in
            let blob = [ev.location, ev.notes, ev.url?.absoluteString].compactMap { $0 }.joined(separator: " ")
            return blob.range(of: #"(?i)(zoom\.us|teams\.microsoft\.com|meet\.google\.com|webex\.com)"#, options: .regularExpression) != nil
        }
    }
}
