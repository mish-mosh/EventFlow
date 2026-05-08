import EventKit

enum SyncError: Error {
    case accessDenied
    case calendarNotFound
}

struct SyncResult: Sendable {
    let created: Int
    let updated: Int
}

actor EventFlowService {
    static let shared = EventFlowService()
    private let store = EKEventStore()
    private let marker = "EVENT_FLOW_SYNC_UID:"

    func sync(sourceID: String, destID: String, rangeDays: Int = 90) async throws -> SyncResult {
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
        var existingByUID: [String: EKEvent] = [:]
        for event in store.events(matching: existingPred) {
            if let uid = extractUID(from: event.notes) {
                existingByUID[uid] = event
            }
        }

        let pred = store.predicateForEvents(
            withStart: .now,
            end: Date(timeIntervalSinceNow: Double(rangeDays) * 86400),
            calendars: [source]
        )

        var created = 0
        var updated = 0
        for event in store.events(matching: pred) {
            let uid = event.calendarItemIdentifier

            if let existing = existingByUID[uid] {
                guard needsUpdate(source: event, dest: existing) else { continue }
                existing.title = event.title
                existing.startDate = event.startDate
                existing.endDate = event.endDate
                existing.isAllDay = event.isAllDay
                existing.location = event.location
                try? store.save(existing, span: .thisEvent, commit: false)
                updated += 1
            } else {
                let copy = EKEvent(eventStore: store)
                copy.title = event.title
                copy.startDate = event.startDate
                copy.endDate = event.endDate
                copy.isAllDay = event.isAllDay
                copy.location = event.location
                copy.notes = "⚠️ Do not delete this line — it is used for sync detection:\n" + marker + uid
                copy.calendar = dest
                try? store.save(copy, span: .thisEvent, commit: false)
                created += 1
            }
        }
        try store.commit()

        let result = SyncResult(created: created, updated: updated)
        let defaults = UserDefaults.standard
        defaults.set(Date.now.timeIntervalSince1970, forKey: "lastSyncTimestamp")
        defaults.set(result.created, forKey: "lastSyncCreated")
        defaults.set(result.updated, forKey: "lastSyncUpdated")

        return result
    }

    func deleteExportedEvents(destIDs: [String]) async throws -> Int {
        guard (try? await store.requestFullAccessToEvents()) == true
        else { throw SyncError.accessDenied }

        let calendars = destIDs.compactMap { store.calendar(withIdentifier: $0) }
        guard !calendars.isEmpty else { return 0 }

        let pred = store.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -365 * 86400),
            end: Date(timeIntervalSinceNow: 400 * 86400),
            calendars: calendars
        )

        var count = 0
        for event in store.events(matching: pred) {
            guard let notes = event.notes, notes.contains(marker) else { continue }
            try? store.remove(event, span: .thisEvent, commit: false)
            count += 1
        }
        try store.commit()
        return count
    }

    private func needsUpdate(source: EKEvent, dest: EKEvent) -> Bool {
        source.title != dest.title
            || source.startDate != dest.startDate
            || source.endDate != dest.endDate
            || source.isAllDay != dest.isAllDay
            || source.location != dest.location
    }

    private func extractUID(from notes: String?) -> String? {
        guard let notes, let range = notes.range(of: marker) else { return nil }
        return String(notes[range.upperBound...])
    }
}
