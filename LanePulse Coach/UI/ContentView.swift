//
//  ContentView.swift
//  LanePulse Coach
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var appContainer: AppContainer

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionRecord.timestamp, ascending: false)],
        animation: .default
    ) private var sessions: FetchedResults<SessionRecord>

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        VStack(spacing: 12) {
                            Text("Training Session")
                                .font(.title3)
                                .bold()
                            Text(session.timestamp, style: .date)
                            Text(session.timestamp, style: .time)
                            Button("Export Sessions") {
                                exportSessions()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .navigationTitle("Details")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.timestamp, style: .time)
                                .font(.headline)
                            Text(session.timestamp, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle(isOn: Binding(
                        get: { appContainer.bleManager.isScanning },
                        set: { $0 ? appContainer.bleManager.startScanning() : appContainer.bleManager.stopScanning() }
                    )) {
                        Label("Scan", systemImage: appContainer.bleManager.isScanning ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addSession) {
                        Label("Add Session", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Sessions")
        } detail: {
            Text("Select a session")
                .foregroundStyle(.secondary)
        }
    }

    private func addSession() {
        do {
            try appContainer.sessionRepository.createSession(at: Date())
            appContainer.analyticsService.track(event: AnalyticsEvent(name: "session_created"))
        } catch {
            appContainer.logger.log(level: .error, message: "Failed to add session: \(error.localizedDescription)")
        }
    }

    private func deleteSessions(offsets: IndexSet) {
        let records = offsets.map { sessions[$0] }
        do {
            try appContainer.sessionRepository.deleteSessions(records)
            appContainer.analyticsService.track(event: AnalyticsEvent(name: "session_deleted", metadata: ["count": "\(records.count)"]))
        } catch {
            appContainer.logger.log(level: .error, message: "Failed to delete sessions: \(error.localizedDescription)")
        }
    }

    private func exportSessions() {
        do {
            let url = try appContainer.exportService.exportSessions()
            appContainer.logger.log(level: .info, message: "Exported sessions to \(url.path)")
        } catch {
            appContainer.logger.log(level: .error, message: "Export error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let previewContainer = AppContainer.makePreview()
    return ContentView()
        .environmentObject(previewContainer)
        .environment(\.managedObjectContext, previewContainer.persistenceController.container.viewContext)
}
