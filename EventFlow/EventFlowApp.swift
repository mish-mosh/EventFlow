import SwiftUI
#if os(iOS)
import BackgroundTasks
#endif

@main
struct EventFlowApp: App {
    init() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.m-shammout.EventFlow.refresh",
            using: nil
        ) { task in
            let sourceID = UserDefaults.standard.string(forKey: "sourceCalendarID") ?? ""
            let destID = UserDefaults.standard.string(forKey: "destCalendarID") ?? ""
            Task {
                let result = try? await EventFlowService.shared
                    .sync(sourceID: sourceID, destID: destID)
                task.setTaskCompleted(success: result != nil)
            }
            Self.scheduleNextRefresh()
        }
        #endif
    }

    #if os(iOS)
    static func scheduleNextRefresh() {
        let minutes = UserDefaults.standard.object(forKey: "refreshIntervalMinutes") as? Int ?? 30
        guard minutes > 0 else { return }
        let req = BGAppRefreshTaskRequest(
            identifier: "com.m-shammout.EventFlow.refresh"
        )
        req.earliestBeginDate = Date(timeIntervalSinceNow: Double(minutes) * 60)
        try? BGTaskScheduler.shared.submit(req)
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
