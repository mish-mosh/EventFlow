import SwiftUI
#if os(iOS)
import BackgroundTasks
#endif

@main
struct CalendarSyncApp: App {
    init() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "de.m-shammout.CalendarSync.refresh",
            using: nil
        ) { task in
            let sourceID = UserDefaults.standard.string(forKey: "sourceCalendarID") ?? ""
            let destID = UserDefaults.standard.string(forKey: "destCalendarID") ?? ""
            Task {
                let count = try? await CalendarSyncService.shared
                    .sync(sourceID: sourceID, destID: destID)
                task.setTaskCompleted(success: count != nil)
            }
            Self.scheduleNextRefresh()
        }
        #endif
    }

    #if os(iOS)
    static func scheduleNextRefresh() {
        let req = BGAppRefreshTaskRequest(
            identifier: "de.m-shammout.CalendarSync.refresh"
        )
        req.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
