import EventKit

enum SyncError: Error {
    case accessDenied
    case calendarNotFound
}

actor CalendarSyncService {
    static let shared = CalendarSyncService()
    private let store = EKEventStore()
    private let marker = "CALENDARSYNC_UID:"

    func sync(sourceID: String, destID: String) async throws -> Int {
        guard (try? await store.requestFullAccessToEvents()) == true
        else { throw SyncError.accessDenied }

        guard
            let source = store.calendar(withIdentifier: sourceID),
            let dest = store.calendar(withIdentifier: destID)
        else { throw SyncError.calendarNotFound }

        let existingPred = store.predicateForEvents(
            withStart: .now,
            end: Date(timeIntervalSinceNow: 400 * 86400),
            calendars: [dest]
        )
        let syncedUIDs = Set(
            store.events(matching: existingPred)
                .compactMap { $0.notes }
                .filter { $0.hasPrefix(marker) }
                .map { String($0.dropFirst(marker.count)) }
        )

        let pred = store.predicateForEvents(
            withStart: .now,
            end: Date(timeIntervalSinceNow: 30 * 86400),
            calendars: [source]
        )

        var count = 0
        for event in store.events(matching: pred) {
            let uid = event.calendarItemIdentifier
            guard !syncedUIDs.contains(uid) else { continue }

            let copy = EKEvent(eventStore: store)
            copy.title = event.title
            copy.startDate = event.startDate
            copy.endDate = event.endDate
            copy.isAllDay = event.isAllDay
            copy.location = event.location
            copy.notes = marker + uid
            copy.calendar = dest
            // TODO: Alarme nicht kopieren — iOS 18.4 Bug: store.save() wirft "Access denied" bei Events mit Alarmen

            try? store.save(copy, span: .thisEvent, commit: false)
            count += 1
        }
        try store.commit()
        return count
    }
}
