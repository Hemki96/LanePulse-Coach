import SwiftUI

struct MappingManagementView: View {
    @ObservedObject var viewModel: SessionDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if viewModel.mappings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keine Zuordnungen")
                        .font(.headline)
                    Text("Verbinde Athlet:innen mit Sensoren, um Live-Daten zu erhalten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                ForEach(viewModel.mappings) { mapping in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(mapping.athleteName)
                                .font(.headline)
                            Spacer()
                            Text(mapping.sensorLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let nickname = mapping.nickname, !nickname.isEmpty {
                            Text(nickname)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Seit \(mapping.since, style: .date) · \(mapping.since, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Mappings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Neu", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MappingEditorView(athletes: viewModel.athletes,
                                  sensors: viewModel.sensors) { athleteId, sensorId, nickname in
                    viewModel.upsertMapping(athleteId: athleteId, sensorId: sensorId, nickname: nickname)
                }
            }
        }
        .task { await viewModel.refresh() }
    }

    private func delete(at offsets: IndexSet) {
        viewModel.removeMappings(at: offsets)
    }
}

private struct MappingEditorView: View {
    let athletes: [AthleteRecord]
    let sensors: [SensorRecord]
    var onSave: (UUID, UUID, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAthlete: UUID?
    @State private var selectedSensor: UUID?
    @State private var nickname: String = ""

    var body: some View {
        Form {
            Section("Athlet:in") {
                Picker("Athlet", selection: Binding(get: { selectedAthlete }, set: { selectedAthlete = $0 })) {
                    Text("Bitte wählen").tag(UUID?.none)
                    ForEach(athletes, id: \.id) { athlete in
                        Text(athlete.name).tag(UUID?.some(athlete.id))
                    }
                }
            }

            Section("Sensor") {
                Picker("Sensor", selection: Binding(get: { selectedSensor }, set: { selectedSensor = $0 })) {
                    Text("Bitte wählen").tag(UUID?.none)
                    ForEach(sensors, id: \.id) { sensor in
                        Text(sensorLabel(sensor)).tag(UUID?.some(sensor.id))
                    }
                }
            }

            Section("Nickname") {
                TextField("optional", text: $nickname)
            }
        }
        .navigationTitle("Mapping anlegen")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") {
                    guard let athleteId = selectedAthlete, let sensorId = selectedSensor else { return }
                    onSave(athleteId, sensorId, nickname.isEmpty ? nil : nickname)
                    dismiss()
                }
                .disabled(selectedAthlete == nil || selectedSensor == nil)
            }
        }
    }

    private func sensorLabel(_ sensor: SensorRecord) -> String {
        let suffix = sensor.id.uuidString.split(separator: "-").last ?? ""
        return "\(sensor.vendor) · \(suffix)"
    }
}
