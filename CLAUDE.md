# CalendarSync

iOS app that copies Exchange calendar events into iCloud via EventKit — no Azure Admin Consent required.

## Tech Stack
- Swift 5.9+, SwiftUI, EventKit, BackgroundTasks
- iOS 17+ target, Xcode 15+
- No external dependencies

## Project Structure
```
CalendarSync/
├── CalendarSync.xcodeproj/
├── Info.plist                    # Bundle keys + permissions + BGTask identifier
└── CalendarSync/
    ├── CalendarSyncApp.swift     # Entry point + BGTask registration
    ├── ContentView.swift         # UI: pickers, sync button, status
    ├── CalendarSyncService.swift # Core sync logic (actor)
    └── SyncStore.swift           # @Observable state + calendar loading
```

## Key Details
- Bundle ID: `de.m-shammout.CalendarSync`
- BGTask identifier: `de.m-shammout.CalendarSync.refresh`
- Info.plist lives at `CalendarSync/Info.plist` (one level above source, outside PBXFileSystemSynchronizedRootGroup)
- `GENERATE_INFOPLIST_FILE = NO`, `INFOPLIST_FILE = Info.plist` in build settings

## Known Limitations
- iOS 18.4+ bug: `store.save()` throws "Access denied" for recurring events with alarms → alarms are not copied
- BGAppRefresh frequency is controlled by iOS, not the app → manual sync button is important
- One-way sync only: new events are added, existing events are not updated
- MDM-managed Exchange accounts may block EventKit access → clear error message shown

## Testing BGTask (Xcode Debugger Console)
```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"de.m-shammout.CalendarSync.refresh"]
```
