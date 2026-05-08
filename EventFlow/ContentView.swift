import SwiftUI
import EventKit

struct ContentView: View {
    @State private var store = SyncStore()
    @State private var showDeleteConfirmation = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Calendars") {
                    calendarPicker(
                        label: "Source",
                        selection: $store.sourceCalendarID,
                        filter: { $0.source.sourceType == .exchange }
                    )
                    calendarPicker(
                        label: "Destination",
                        selection: $store.destCalendarID,
                        filter: { $0.source.sourceType == .calDAV }
                    )
                }

                Section {
                    Button {
                        Task { await store.sync() }
                    } label: {
                        HStack {
                            Spacer()
                            if store.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Syncing…")
                            } else {
                                Text("Sync Now")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(store.isSyncing || store.sourceCalendarID == nil || store.destCalendarID == nil)
                }

                Section("Status") {
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    if let date = store.lastSyncDate {
                        Label(
                            "Last sync: \(date.formatted(date: .omitted, time: .shortened))",
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                        Text("\(store.lastSyncCreated) created, \(store.lastSyncUpdated) updated")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Settings") {
                    Picker("Sync Range", selection: $store.syncRangeDays) {
                        ForEach(SyncStore.syncRangeDaysOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    Picker("Auto-Sync", selection: $store.refreshIntervalMinutes) {
                        ForEach(SyncStore.refreshIntervalOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? "Off" : "\(minutes) min")
                                .tag(minutes)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if store.isDeleting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Deleting…")
                            } else {
                                Label("Delete Exported Events", systemImage: "trash")
                            }
                            Spacer()
                        }
                    }
                    .disabled(store.isDeleting || store.destCalendarID == nil)
                }
            }
            .navigationTitle("EventFlow")
            .confirmationDialog(
                deleteConfirmationMessage,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await store.deleteExportedEvents() }
                }
            }
            .alert(
                "Deleted",
                isPresented: showDeleteResult
            ) {
                Button("OK") { store.lastDeleteCount = nil }
            } message: {
                Text("\(store.lastDeleteCount ?? 0) events deleted.")
            }
        }
        .task {
            await store.requestAccessAndLoad()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadLastSyncFromDefaults()
            }
        }
    }

    private var showDeleteResult: Binding<Bool> {
        Binding(
            get: { store.lastDeleteCount != nil },
            set: { if !$0 { store.lastDeleteCount = nil } }
        )
    }

    private var deleteConfirmationMessage: String {
        let name = store.destCalendarName ?? "destination calendar"
        return "Delete all events created by EventFlow from \"\(name)\"?"
    }

    @ViewBuilder
    private func calendarPicker(
        label: String,
        selection: Binding<String?>,
        filter: @escaping (EKCalendar) -> Bool
    ) -> some View {
        let calendars = store.allCalendars.filter(filter)
        if calendars.isEmpty {
            LabeledContent(label) {
                Text("Not found")
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker(label, selection: selection) {
                Text("Select").tag(String?.none)
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    Text(cal.title).tag(Optional(cal.calendarIdentifier))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
