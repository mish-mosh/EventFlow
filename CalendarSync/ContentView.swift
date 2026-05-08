import SwiftUI
import EventKit

struct ContentView: View {
    @State private var store = SyncStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("Kalender") {
                    calendarPicker(
                        label: "Quelle",
                        selection: $store.sourceCalendarID,
                        filter: { $0.source.sourceType == .exchange }
                    )
                    calendarPicker(
                        label: "Ziel",
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
                                Text("Sync läuft…")
                            } else {
                                Text("Jetzt syncen")
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
                            "Letzter Sync: \(date.formatted(date: .omitted, time: .shortened))",
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                        Text("\(store.lastSyncCount) Events kopiert")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Auto-Sync (alle 30 Min)", isOn: $store.autoSyncEnabled)
                }
            }
            .navigationTitle("CalendarSync")
        }
        .task {
            await store.requestAccessAndLoad()
        }
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
                Text("Nicht gefunden")
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker(label, selection: selection) {
                Text("Auswählen").tag(String?.none)
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
