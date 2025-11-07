import SwiftUI

struct SessionDashboardView: View {
    @StateObject private var viewModel: SessionDashboardViewModel
    @State private var showingSettings = false
    @State private var showingMappings = false
    @State private var exportFormat: DataExportFormat = .csv
    @State private var exportSuccessMessage: String?

    init(session: SessionRecord, container: AppContainer) {
        _viewModel = StateObject(wrappedValue: SessionDashboardViewModel(session: session, container: container))
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            Picker("Ansicht", selection: $viewModel.viewMode) {
                ForEach(SessionDashboardViewModel.ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("view_mode_picker")

            Group {
                switch viewModel.viewMode {
                case .board:
                    boardGrid
                case .scoreboard:
                    ScoreboardView(viewModel: viewModel)
                }
            }

            if let snapshot = viewModel.selectedSnapshot, let metric = viewModel.selectedMetric {
                DetailPaneView(snapshot: snapshot,
                               metric: metric,
                               viewModel: viewModel)
            } else {
                Text("Tippe auf eine Kachel für Details")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .navigationTitle("Live Board")
        .toolbar { toolbarContent }
        .task { await viewModel.refresh() }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                CoachSettingsView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingMappings) {
            NavigationStack {
                MappingManagementView(viewModel: viewModel)
            }
        }
        .alert("Fehler", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unbekannter Fehler")
        }
        .alert("Export abgeschlossen", isPresented: Binding(
            get: { exportSuccessMessage != nil },
            set: { if !$0 { exportSuccessMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportSuccessMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Session")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(viewModel.selectedSnapshot?.lastUpdated ?? Date(), style: .time)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var boardGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: viewModel.layout.columns), spacing: 12) {
                ForEach(viewModel.snapshots) { snapshot in
                    BoardTileView(snapshot: snapshot,
                                  metrics: viewModel.visibleMetrics,
                                  zoneStops: viewModel.zoneFractionColorStops(),
                                  displayProvider: { metric in
                        viewModel.displayData(for: snapshot, metric: metric)
                    },
                                  onTap: { metric in
                        viewModel.select(snapshot: snapshot, metric: metric)
                    },
                                  onLongPress: {
                        viewModel.markInterval(for: snapshot)
                    })
                }
            }
            .animation(.easeInOut, value: viewModel.layout)
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("board_scroll")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Label("Einstellungen", systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Einstellungen")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingMappings = true
            } label: {
                Label("Mappings", systemImage: "link")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Mappings")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Format", selection: $exportFormat) {
                    Text("CSV").tag(DataExportFormat.csv)
                    Text("JSON").tag(DataExportFormat.json)
                }
                Button {
                    export()
                } label: {
                    Label("Export starten", systemImage: "arrow.down.doc")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Export")
        }
    }

    private func export() {
        do {
            let url = try viewModel.exportData(format: exportFormat)
            exportSuccessMessage = "Export gespeichert in \(url.lastPathComponent)"
        } catch {
            viewModel.errorMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

private struct BoardTileView: View {
    let snapshot: SessionDashboardViewModel.AthleteSnapshot
    let metrics: [CoachMetric]
    let zoneStops: [Double]
    let displayProvider: (CoachMetric) -> MetricDisplayData
    let onTap: (CoachMetric) -> Void
    let onLongPress: () -> Void

    var body: some View {
        let primaryMetric = metrics.first ?? .heartRate
        let primaryData = displayProvider(primaryMetric)
        let secondaryMetrics = Array(metrics.dropFirst())
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(snapshot.name)
                    .font(.headline)
                Spacer()
                if let delta = primaryData.trendDelta {
                    TrendBadge(delta: delta)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryData.value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                if let unit = primaryData.unit {
                    Text(unit.uppercased())
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)
                }
            }
            if !secondaryMetrics.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                HStack(alignment: .top, spacing: 12) {
                    ForEach(secondaryMetrics, id: \.rawValue) { metric in
                        let data = displayProvider(metric)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(data.value)
                                .font(.headline)
                            if let unit = data.unit {
                                Text(unit)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            ZoneIndicator(fraction: primaryData.zoneFraction, stops: zoneStops)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor(for: primaryData.zoneFraction))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { onTap(primaryMetric) }
        .onLongPressGesture(perform: onLongPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.name) \(primaryData.title)")
        .accessibilityValue(primaryData.value)
        .accessibilityIdentifier("board_tile_\(snapshot.id.uuidString)")
    }

    private func backgroundColor(for fraction: Double?) -> Color {
        guard let fraction else { return Color(.secondarySystemBackground) }
        let stops = zoneStops
        let palette: [Color] = [.blue.opacity(0.35), .green.opacity(0.35), .yellow.opacity(0.35), .orange.opacity(0.35), .red.opacity(0.4)]
        for (index, stop) in stops.enumerated() {
            if fraction < stop { return palette[min(index, palette.count - 1)] }
        }
        return palette.last ?? Color.red.opacity(0.4)
    }
}

private struct TrendBadge: View {
    let delta: Int

    var body: some View {
        let systemName: String
        let tint: Color
        if delta > 3 {
            systemName = "arrow.up"
            tint = .red
        } else if delta < -3 {
            systemName = "arrow.down"
            tint = .green
        } else {
            systemName = "arrow.right"
            tint = .yellow
        }
        return Label("Trend", systemImage: systemName)
            .labelStyle(.iconOnly)
            .imageScale(.medium)
            .foregroundStyle(tint)
            .padding(6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct ZoneIndicator: View {
    let fraction: Double?
    let stops: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Zone")
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                    if let fraction {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(zoneColor(for: fraction))
                            .frame(width: geometry.size.width * CGFloat(min(max(fraction, 0), 1)))
                    }
                    HStack(spacing: 0) {
                        ForEach(stops, id: \.self) { stop in
                            Rectangle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 1)
                                .offset(x: geometry.size.width * CGFloat(stop))
                        }
                    }
                }
            }
            .frame(height: 10)
        }
    }

    private func zoneColor(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.6: return .blue
        case ..<0.7: return .green
        case ..<0.8: return .yellow
        case ..<0.9: return .orange
        default: return .red
        }
    }
}

private struct DetailPaneView: View {
    let snapshot: SessionDashboardViewModel.AthleteSnapshot
    let metric: CoachMetric
    @ObservedObject var viewModel: SessionDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(snapshot.name)
                        .font(.headline)
                    Text(metric.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let recovery = viewModel.recoverySeconds(for: snapshot) {
                    RecoveryBadge(seconds: recovery)
                }
                Button {
                    viewModel.markInterval(for: snapshot)
                } label: {
                    Label("Intervall", systemImage: "flag")
                }
                .buttonStyle(.bordered)
            }
            TimelineView(snapshot: snapshot, markers: viewModel.markersForAthlete(snapshot))
            markerList
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("detail_pane")
    }

    private var markerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intervalle")
                .font(.caption)
                .foregroundStyle(.secondary)
            let markers = viewModel.markersForAthlete(snapshot).suffix(5)
            if markers.isEmpty {
                Text("Noch keine Marken")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(markers.enumerated()), id: \.element.id) { entry in
                    HStack {
                        Text("#\(entry.offset + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.element.timestamp, style: .time)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

private struct TimelineView: View {
    let snapshot: SessionDashboardViewModel.AthleteSnapshot
    let markers: [SessionDashboardViewModel.IntervalMarker]

    var body: some View {
        let samples = recentSamples()
        return VStack(alignment: .leading, spacing: 8) {
            Text("Timeline · letzte 2 Minuten")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                Canvas { context, size in
                    guard samples.count > 1 else { return }
                    let points = normalizedPoints(in: size)
                    var path = Path()
                    path.move(to: points.first!)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(path, with: .color(.accentColor), lineWidth: 2)

                    for marker in markers {
                        if let position = markerPosition(marker, size: size) {
                            var line = Path()
                            line.move(to: CGPoint(x: position, y: 0))
                            line.addLine(to: CGPoint(x: position, y: size.height))
                            context.stroke(line, with: .color(.red.opacity(0.6)), lineWidth: 2)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            }
            .frame(height: 120)
        }
    }

    private func recentSamples() -> [HRSampleRecord] {
        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let filtered = snapshot.samples.filter { $0.timestamp >= twoMinutesAgo }
        if filtered.count >= 2 {
            return filtered
        }
        return snapshot.samples
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        let samples = recentSamples()
        let minHr = Double(samples.map { Int($0.heartRate) }.min() ?? 40)
        let maxHr = Double(samples.map { Int($0.heartRate) }.max() ?? 200)
        let range = max(maxHr - minHr, 1)
        let start = samples.first?.timestamp ?? Date()
        let end = samples.last?.timestamp ?? start
        let duration = max(end.timeIntervalSince(start), 1)
        return samples.map { sample in
            let xFraction = sample.timestamp.timeIntervalSince(start) / duration
            let yFraction = (Double(sample.heartRate) - minHr) / range
            let x = size.width * xFraction
            let y = size.height * (1 - yFraction)
            return CGPoint(x: x, y: y)
        }
    }

    private func markerPosition(_ marker: SessionDashboardViewModel.IntervalMarker, size: CGSize) -> CGFloat? {
        let samples = recentSamples()
        guard let start = samples.first?.timestamp, let end = samples.last?.timestamp, start < end else {
            return nil
        }
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return nil }
        let clamped = min(max(marker.timestamp, start), end)
        let fraction = clamped.timeIntervalSince(start) / duration
        return size.width * fraction
    }
}

private struct RecoveryBadge: View {
    let seconds: TimeInterval

    var body: some View {
        VStack(alignment: .trailing) {
            Text("Recovery")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(format(seconds: seconds))
                .font(.title3).bold()
        }
        .padding(8)
        .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func format(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let remainingSeconds = total % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
        return "0:\(String(format: "%02d", remainingSeconds))"
    }
}

private struct ScoreboardView: View {
    @ObservedObject var viewModel: SessionDashboardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Scoreboard")
                    .font(.title2)
                    .bold()
                ForEach(viewModel.snapshots.prefix(8)) { snapshot in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(snapshot.name)
                                .font(.title3)
                                .bold()
                            Spacer()
                            Text("\(snapshot.currentBpm ?? 0) bpm")
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .foregroundStyle(scoreColor(for: snapshot))
                        }
                        IntervalChips(markers: viewModel.markersForAthlete(snapshot))
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("scoreboard_tile_\(snapshot.id.uuidString)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("scoreboard_scroll")
    }

    private func scoreColor(for snapshot: SessionDashboardViewModel.AthleteSnapshot) -> Color {
        guard let fraction = snapshot.zoneFraction else { return .primary }
        switch fraction {
        case ..<0.6: return .blue
        case ..<0.7: return .green
        case ..<0.8: return .yellow
        case ..<0.9: return .orange
        default: return .red
        }
    }
}

private struct IntervalChips: View {
    let markers: [SessionDashboardViewModel.IntervalMarker]

    var body: some View {
        if markers.isEmpty {
            Text("Keine Intervalle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(markers.suffix(12)) { marker in
                        Text(marker.timestamp, style: .time)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let container = AppContainer.makePreview()
    let session = (try? container.sessionRepository.fetchAllSessions().first) ?? (try? container.sessionRepository.createSession(SessionInput()))
    return NavigationStack {
        if let session {
            SessionDashboardView(session: session, container: container)
        } else {
            Text("Keine Session")
        }
    }
}
