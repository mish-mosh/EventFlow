import AppIntents

struct SyncCalendarsIntent: AppIntent {
    static let title: LocalizedStringResource = "Sync Calendars"
    static let description: IntentDescription = "Copies Exchange calendar events to iCloud"

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let sourceID = UserDefaults.standard.string(forKey: "sourceCalendarID") ?? ""
        let destID = UserDefaults.standard.string(forKey: "destCalendarID") ?? ""

        guard !sourceID.isEmpty, !destID.isEmpty else {
            throw SyncIntentError.noCalendarsConfigured
        }

        let result = try await EventFlowService.shared.sync(sourceID: sourceID, destID: destID)
        return .result(value: result.created + result.updated)
    }
}

enum SyncIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noCalendarsConfigured

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noCalendarsConfigured:
            "Please select source and destination calendars in EventFlow first"
        }
    }
}

struct EventFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncCalendarsIntent(),
            phrases: [
                "Sync calendars with \(.applicationName)",
                "Sync calendar with \(.applicationName)"
            ],
            shortTitle: "Sync Calendars",
            systemImageName: "calendar.badge.arrow.2.trianglepath"
        )
    }
}
