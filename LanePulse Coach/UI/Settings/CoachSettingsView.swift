import SwiftUI

struct CoachSettingsView: View {
    @ObservedObject var viewModel: SessionDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    private let zoneKeys: [String] = ["zone1", "zone2", "zone3", "zone4"]

    var body: some View {
        Form {
            Section(header: Text("Board Layout"), footer: Text("Wähle die gewünschte Anzahl an Kacheln")) {
                Picker("Layout", selection: Binding(get: { viewModel.layout }, set: { viewModel.updateLayout($0) })) {
                    ForEach(BoardLayout.allCases) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Kennzahlen"), footer: Text("Aktiviere die Kennzahlen, die in den Kacheln angezeigt werden.")) {
                ForEach(CoachMetric.allCases) { metric in
                    Toggle(isOn: Binding(
                        get: { viewModel.visibleMetrics.contains(metric) },
                        set: { isOn in
                            if isOn {
                                viewModel.toggleMetric(metric)
                            } else {
                                viewModel.toggleMetric(metric)
                            }
                        }
                    )) {
                        Text(metric.displayName)
                    }
                }
            }

            Section(header: Text("Zonenmodell"), footer: Text("Grenzen relativ zur HFmax")) {
                ForEach(zoneKeys, id: \.self) { key in
                    HStack {
                        Text(label(for: key))
                        Spacer()
                        Slider(value: Binding(
                            get: { viewModel.zoneThresholds[key] ?? SessionDashboardViewModel.defaultZoneThresholds[key] ?? 0.6 },
                            set: { newValue in viewModel.updateThreshold(key: key, value: newValue) }
                        ), in: 0.5...1.05, step: 0.01)
                        let percentage = Int(((viewModel.zoneThresholds[key] ?? SessionDashboardViewModel.defaultZoneThresholds[key] ?? 0.6) * 100).rounded())
                        Text("\(percentage)%")
                            .font(.caption)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .navigationTitle("Einstellungen")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    private func label(for key: String) -> String {
        switch key {
        case "zone1": return "Zone 1"
        case "zone2": return "Zone 2"
        case "zone3": return "Zone 3"
        case "zone4": return "Zone 4"
        default: return key
        }
    }
}
