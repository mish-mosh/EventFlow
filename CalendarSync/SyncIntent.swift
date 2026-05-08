import AppIntents

struct SyncCalendarsIntent: AppIntent {
    static let title: LocalizedStringResource = "Kalender synchronisieren"
    static let description: IntentDescription = "Kopiert Exchange-Kalenderevents nach iCloud"

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let sourceID = UserDefaults.standard.string(forKey: "sourceCalendarID") ?? ""
        let destID = UserDefaults.standard.string(forKey: "destCalendarID") ?? ""

        guard !sourceID.isEmpty, !destID.isEmpty else {
            throw SyncIntentError.noCalendarsConfigured
        }

        let count = try await CalendarSyncService.shared.sync(sourceID: sourceID, destID: destID)
        return .result(value: count)
    }
}

enum SyncIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noCalendarsConfigured

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noCalendarsConfigured:
            "Bitte zuerst Quell- und Zielkalender in CalendarSync auswählen"
        }
    }
}

struct CalendarSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncCalendarsIntent(),
            phrases: [
                "Synchronisiere Kalender mit \(.applicationName)",
                "Sync Kalender mit \(.applicationName)"
            ],
            shortTitle: "Kalender syncen",
            systemImageName: "calendar.badge.arrow.2.trianglepath"
        )
    }
}
