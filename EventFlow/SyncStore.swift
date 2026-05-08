import EventKit
import Observation

@Observable
class SyncStore {
    static let refreshIntervalOptions = [0, 5, 15, 30]
    static let syncRangeDaysOptions = [30, 60, 90, 180]

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
    var lastSyncCreated: Int = 0
    var lastSyncUpdated: Int = 0
    var isSyncing = false
    var isDeleting = false
    var lastDeleteCount: Int?
    var errorMessage: String?
    var refreshIntervalMinutes: Int {
        didSet { defaults.set(refreshIntervalMinutes, forKey: "refreshIntervalMinutes") }
    }
    var syncRangeDays: Int {
        didSet { defaults.set(syncRangeDays, forKey: "syncRangeDays") }
    }

    var autoSyncEnabled: Bool { refreshIntervalMinutes > 0 }

    var destCalendarName: String? {
        guard let id = destCalendarID else { return nil }
        return allCalendars.first { $0.calendarIdentifier == id }?.title
    }

    init() {
        let saved = defaults.object(forKey: "refreshIntervalMinutes") as? Int
        self.refreshIntervalMinutes = saved ?? 30
        let savedRange = defaults.object(forKey: "syncRangeDays") as? Int
        self.syncRangeDays = savedRange ?? 90
        loadLastSyncFromDefaults()
    }

    func loadLastSyncFromDefaults() {
        let timestamp = defaults.double(forKey: "lastSyncTimestamp")
        if timestamp > 0 {
            lastSyncDate = Date(timeIntervalSince1970: timestamp)
            lastSyncCreated = defaults.integer(forKey: "lastSyncCreated")
            lastSyncUpdated = defaults.integer(forKey: "lastSyncUpdated")
        }
    }

    func requestAccessAndLoad() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        await MainActor.run { loadCalendars() }
    }

    func sync() async {
        guard let sourceID = sourceCalendarID, let destID = destCalendarID else {
            errorMessage = "Please select source and destination calendars"
            return
        }
        isSyncing = true
        errorMessage = nil
        do {
            _ = try await EventFlowService.shared.sync(sourceID: sourceID, destID: destID, rangeDays: syncRangeDays)
            loadLastSyncFromDefaults()
        } catch SyncError.accessDenied {
            errorMessage = "No calendar access — please allow in Settings"
        } catch SyncError.calendarNotFound {
            errorMessage = "Calendar not found — is Exchange visible?"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }

    func deleteExportedEvents() async {
        guard let destID = destCalendarID else {
            errorMessage = "No destination calendar configured"
            return
        }
        isDeleting = true
        errorMessage = nil
        do {
            let count = try await EventFlowService.shared.deleteExportedEvents(destIDs: [destID])
            lastSyncCreated = 0
            lastSyncUpdated = 0
            lastSyncDate = nil
            lastDeleteCount = count
        } catch SyncError.accessDenied {
            errorMessage = "No calendar access — please allow in Settings"
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }

    private func loadCalendars() {
        allCalendars = eventStore.calendars(for: .event)
        let calendarIDs = Set(allCalendars.map(\.calendarIdentifier))

        let savedSource = defaults.string(forKey: "sourceCalendarID")
        if let savedSource, calendarIDs.contains(savedSource) {
            sourceCalendarID = savedSource
        }

        let savedDest = defaults.string(forKey: "destCalendarID")
        if let savedDest, calendarIDs.contains(savedDest) {
            destCalendarID = savedDest
        }
    }
}
