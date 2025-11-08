//
//  ContentView.swift
//  LanePulse Coach
//

import SwiftUI
import CoreData

struct ContentView: View {
    private enum Tab: Hashable {
        case sessions
        case settings
    }

    @StateObject private var viewModel: SessionListViewModel
    @State private var selectedTab: Tab = .sessions
    @State private var selectedSessionID: NSManagedObjectID?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: SessionListViewModel(container: container))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionsSplitView(viewModel: viewModel,
                              container: container,
                              selectedSessionID: $selectedSessionID)
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.sessions)

            SettingsTabView(container: container,
                             selectedSession: selectedSession,
                             focusSessionsTab: { selectedTab = .sessions })
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .onAppear {
            ensureInitialSelection()
        }
        .onChange(of: viewModel.snapshot.items) { _ in
            ensureSelectionConsistency()
        }
        .onChange(of: selectedTab) { _ in
            ensureSelectionConsistency()
        }
        .accessibilityElement(children: .contain)
    }

    private var selectedSession: SessionRecord? {
        guard let selectedSessionID else { return nil }
        return viewModel.session(for: selectedSessionID)
    }

    private func ensureInitialSelection() {
        guard selectedSessionID == nil,
              let first = viewModel.snapshot.items.first else { return }
        selectedSessionID = first.objectID
    }

    private func ensureSelectionConsistency() {
        if selectedSessionID == nil {
            selectedSessionID = viewModel.snapshot.items.first?.objectID
        } else if let selectedSessionID,
                    !viewModel.snapshot.items.contains(where: { $0.objectID == selectedSessionID }) {
            self.selectedSessionID = viewModel.snapshot.items.first?.objectID
        }
    }

}

private struct SessionsSplitView: View {
    @ObservedObject var viewModel: SessionListViewModel
    let container: AppContainer
    @Binding var selectedSessionID: NSManagedObjectID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSessionID) {
                ForEach(viewModel.snapshot.items) { item in
                    SessionRow(item: item)
                        .tag(item.objectID)
                }
                .onDelete(perform: viewModel.deleteSessions)
            }
            .listStyle(.insetGrouped)
            .toolbar { toolbarContent }
            .navigationTitle("Sessions")
        } detail: {
            if let selectedSessionID,
               let session = viewModel.session(for: selectedSessionID) {
                SessionDashboardView(session: session, container: container)
            } else {
                PlaceholderView()
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            .accessibilityLabel("Session hinzufügen")
        }
    }
}

private struct SessionRow: View {
    let item: SessionListViewModel.Snapshot.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.startDate, style: .time)
                .font(.headline)
            Text(item.startDate, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("session_row_\(item.sessionID.uuidString)")
        .accessibilityLabel("Session gestartet am \(item.startDate.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityHint("Öffnet die Sessiondetails")
    }
}

private struct PlaceholderView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .imageScale(.large)
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Session wählen")
                    .font(.title3)
                    .bold()
                Text("Starte eine Session, um Board, Scoreboard und Detailansicht zu öffnen.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsTabView: View {
    let container: AppContainer
    let selectedSession: SessionRecord?
    let focusSessionsTab: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Session-Einstellungen")) {
                    if let selectedSession {
                        NavigationLink {
                            CoachSettingsContainer(session: selectedSession, container: container)
                        } label: {
                            Label("Coach-Einstellungen", systemImage: "slider.horizontal.3")
                        }

                        NavigationLink {
                            MappingManagementContainer(session: selectedSession, container: container)
                        } label: {
                            Label("Sensor-Mappings", systemImage: "link")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Keine Session ausgewählt")
                                .font(.headline)
                            Text("Wechsle in den Sessions-Tab und wähle eine Session, um spezifische Einstellungen zu öffnen.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button(action: focusSessionsTab) {
                                Label("Zu den Sessions", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                    }
                }

                Section(header: Text("Barrierefreiheit")) {
                    NavigationLink {
                        AccessibilityTipsView()
                    } label: {
                        Label("Tipps für VoiceOver & AssistiveTouch", systemImage: "figure.wave")
                    }
                }

                Section(header: Text("Support")) {
                    NavigationLink {
                        SupportInfoView()
                    } label: {
                        Label("Kontakt & Feedback", systemImage: "message")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Einstellungen")
        }
    }
}

private struct CoachSettingsContainer: View {
    @StateObject private var viewModel: SessionDashboardViewModel

    init(session: SessionRecord, container: AppContainer) {
        _viewModel = StateObject(wrappedValue: SessionDashboardViewModel(session: session, container: container))
    }

    var body: some View {
        CoachSettingsView(viewModel: viewModel)
    }
}

private struct MappingManagementContainer: View {
    @StateObject private var viewModel: SessionDashboardViewModel

    init(session: SessionRecord, container: AppContainer) {
        _viewModel = StateObject(wrappedValue: SessionDashboardViewModel(session: session, container: container))
    }

    var body: some View {
        MappingManagementView(viewModel: viewModel)
    }
}

private struct AccessibilityTipsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Barrierefreiheit")
                    .font(.title2)
                    .bold()
                VStack(alignment: .leading, spacing: 12) {
                    Label("VoiceOver", systemImage: "ear")
                        .font(.headline)
                    Text("Alle wesentlichen Informationen sind als kombinierte Elemente vertont. Nutze das Rotor-Menü, um schnell zwischen Sessions und Kennzahlen zu navigieren.")
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("AssistiveTouch", systemImage: "hand.raised")
                        .font(.headline)
                    Text("Buttons und Steuerelemente haben großzügige Touch-Ziele und klare Icons, sodass AssistiveTouch-Bedienungen zuverlässig funktionieren.")
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("Dynamische Schrift", systemImage: "textformat.size")
                        .font(.headline)
                    Text("Die Oberfläche passt sich automatisch an deine bevorzugte Textgröße an und reduziert Inhalte für sehr große Schriftgrößen auf gut lesbare Layouts.")
                        .font(.body)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Barrierefreiheit")
    }
}

private struct SupportInfoView: View {
    var body: some View {
        List {
            Section("Kontakt") {
                Label("coach@lanepulse.app", systemImage: "envelope")
                    .font(.body)
                    .accessibilityLabel("E-Mail coach@lanepulse.app")
                Label("+49 123 456789", systemImage: "phone")
                    .font(.body)
                    .accessibilityLabel("Telefonnummer +49 123 456789")
            }

            Section("Feedback") {
                Text("Wir freuen uns über Rückmeldungen zu Bedienbarkeit, Dark Mode und Unterstützung von Rechts-nach-Links-Sprachen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Support")
    }
}

#Preview {
    let previewContainer = AppContainer.makePreview()
    return ContentView(container: previewContainer)
        .environmentObject(previewContainer)
        .environment(\.managedObjectContext, previewContainer.persistenceController.container.viewContext)
}
