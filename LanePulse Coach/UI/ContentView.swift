//
//  ContentView.swift
//  LanePulse Coach
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var viewModel: SessionListViewModel
    private let container: AppContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: SessionListViewModel(container: container))
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack {
                    sessionListView
                        .navigationTitle("Sessions")
                }
            } else {
                NavigationSplitView {
                    sessionListView
                        .navigationTitle("Sessions")
                } detail: {
                    placeholderDetail
                }
            }
        }
    }
}

#Preview {
    let previewContainer = AppContainer.makePreview()
    return ContentView(container: previewContainer)
        .environmentObject(previewContainer)
        .environment(\.managedObjectContext, previewContainer.persistenceController.container.viewContext)
}

private extension ContentView {
    @ViewBuilder
    var sessionListView: some View {
        List {
            ForEach(viewModel.snapshot.items) { item in
                NavigationLink {
                    if let session = viewModel.session(for: item.objectID) {
                        SessionDashboardView(session: session, container: container)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Session konnte nicht geladen werden")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.startDate, style: .time)
                            .font(.headline)
                        Text(item.startDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("session_row_\(item.sessionID.uuidString)")
            }
            .onDelete(perform: viewModel.deleteSessions)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: viewModel.toggleScanning) {
                    Label("Scan", systemImage: viewModel.isScanning ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel(viewModel.isScanning ? "Scan stoppen" : "Scan starten")
                .accessibilityValue(viewModel.isScanning ? "Aktiv" : "Inaktiv")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.addSession) {
                    Label("Add Session", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    var placeholderDetail: some View {
        VStack(spacing: 12) {
            Text("Session wählen")
                .font(.title3)
                .bold()
            Text("Starte eine Session, um Board, Scoreboard und Detailansicht zu öffnen.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
