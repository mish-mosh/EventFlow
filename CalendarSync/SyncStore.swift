import EventKit
import Observation

@Observable
class SyncStore {
    private let eventStore = EKEventStore()
    private let defaults = UserDefaults.standard

    var allCalendars: [EKCalendar] = []

    var sourceCalendarID: String? {
        didSet { defaults.set(sourceCalendarID, forKey: "sourceCalendarID") }
    }
    var destCalendarID: String? {
        didSet { defaults.set(destCalendarID, forKey: "destCalendarID") }
    }

    var lastSyncDate: Date?
    var lastSyncCount: Int = 0
    var isSyncing = false
    var errorMessage: String?
    var autoSyncEnabled = true

    func requestAccessAndLoad() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        await MainActor.run { loadCalendars() }
    }

    func sync() async {
        guard let sourceID = sourceCalendarID, let destID = destCalendarID else {
            errorMessage = "Bitte Quell- und Zielkalender auswählen"
            return
        }
        isSyncing = true
        errorMessage = nil
        do {
            let count = try await CalendarSyncService.shared.sync(sourceID: sourceID, destID: destID)
            lastSyncCount = count
            lastSyncDate = .now
        } catch SyncError.accessDenied {
            errorMessage = "Kein Kalenderzugriff — bitte in Einstellungen erlauben"
        } catch SyncError.calendarNotFound {
            errorMessage = "Kalender nicht gefunden — Exchange sichtbar?"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }

    private func loadCalendars() {
        allCalendars = eventStore.calendars(for: .event)
        let calendarIDs = Set(allCalendars.map(\.calendarIdentifier))

        let savedSource = defaults.string(forKey: "sourceCalendarID")
        if let savedSource, calendarIDs.contains(savedSource) {
            sourceCalendarID = savedSource
        } else {
            sourceCalendarID = allCalendars
                .first { $0.source.sourceType == .exchange }?
                .calendarIdentifier
        }

        let savedDest = defaults.string(forKey: "destCalendarID")
        if let savedDest, calendarIDs.contains(savedDest) {
            destCalendarID = savedDest
        } else {
            destCalendarID = allCalendars
                .first { $0.source.sourceType == .calDAV }?
                .calendarIdentifier
        }
    }
}
