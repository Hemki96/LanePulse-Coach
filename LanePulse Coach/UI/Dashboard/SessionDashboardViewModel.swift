import Foundation
import CoreData
#if canImport(Combine)
import Combine
#endif

enum BoardLayout: String, CaseIterable, Identifiable {
    case twoByTwo
    case threeByThree
    case fourByTwo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twoByTwo: return "2×2"
        case .threeByThree: return "3×3"
        case .fourByTwo: return "4×2"
        }
    }

    var columns: Int {
        switch self {
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByTwo: return 4
        }
    }

    var rows: Int {
        switch self {
        case .twoByTwo: return 2
        case .threeByThree: return 3
        case .fourByTwo: return 2
        }
    }

    var tileCount: Int { columns * rows }

    static func layout(for index: Int) -> BoardLayout {
        let all = Self.allCases
        if index >= 0 && index < all.count {
            return all[index]
        }
        return .twoByTwo
    }
}

enum CoachMetric: String, CaseIterable, Identifiable {
    case heartRate
    case averageHeartRate
    case maxHeartRate
    case minHeartRate
    case zoneFraction
    case timeInZone
    case recovery
    case trainingLoad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heartRate: return "HR"
        case .averageHeartRate: return "Avg HR"
        case .maxHeartRate: return "Max HR"
        case .minHeartRate: return "Min HR"
        case .zoneFraction: return "Zone"
        case .timeInZone: return "Zone Time"
        case .recovery: return "Recovery"
        case .trainingLoad: return "Load"
        }
    }

    var unit: String? {
        switch self {
        case .heartRate, .averageHeartRate, .maxHeartRate, .minHeartRate:
            return "bpm"
        case .zoneFraction:
            return nil
        case .timeInZone:
            return "min"
        case .recovery:
            return "s"
        case .trainingLoad:
            return nil
        }
    }

    static var defaults: [CoachMetric] {
        [.heartRate, .averageHeartRate, .zoneFraction, .recovery]
    }
}

struct MetricDisplayData {
    let title: String
    let value: String
    let unit: String?
    let trendDelta: Int?
    let zoneFraction: Double?
}

@MainActor
final class SessionDashboardViewModel: ObservableObject {
    struct AthleteSnapshot: Identifiable {
        let id: UUID
        let name: String
        let maxHr: Int
        let samples: [HRSampleRecord]
        let currentBpm: Int?
        let averageBpm: Double?
        let maxBpm: Int?
        let minBpm: Int?
        let lastUpdated: Date?
        let trendDelta: Int?
        let zoneFraction: Double?
        let totalZoneSeconds: TimeInterval
    }

    struct IntervalMarker: Identifiable {
        let id: UUID
        let timestamp: Date
        let athleteId: UUID?
    }

    struct MappingDisplay: Identifiable {
        let id: UUID
        let athleteId: UUID
        let athleteName: String
        let sensorId: UUID
        let sensorLabel: String
        let since: Date
        let nickname: String?
    }

    enum ViewMode: String, CaseIterable, Identifiable {
        case board
        case scoreboard

        var id: String { rawValue }

        var title: String {
            switch self {
            case .board: return "Board"
            case .scoreboard: return "Scoreboard"
            }
        }
    }

    private let session: SessionRecord
    private let container: AppContainer
    private let coachProfileId: UUID
    private let latencyMonitor: LatencyMonitoring

    @Published var layout: BoardLayout = .twoByTwo {
        didSet { persistConfig() }
    }
    @Published var visibleMetrics: [CoachMetric] = CoachMetric.defaults {
        didSet { persistConfig() }
    }
    @Published var zoneThresholds: [String: Double] = SessionDashboardViewModel.defaultZoneThresholds {
        didSet { persistConfig() }
    }
    @Published var snapshots: [AthleteSnapshot] = []
    @Published var selectedSnapshot: AthleteSnapshot?
    @Published var selectedMetric: CoachMetric? = .heartRate
    @Published var viewMode: ViewMode = .board
    @Published var intervalMarkers: [IntervalMarker] = []
    @Published var mappings: [MappingDisplay] = []
    @Published var athletes: [AthleteRecord] = []
    @Published var sensors: [SensorRecord] = []
    @Published var errorMessage: String?
    @Published var exportProgress: DataExportProgress?
    @Published var isExporting: Bool = false
    @Published var lastExportURL: URL?

    init(session: SessionRecord, container: AppContainer, coachProfileId: UUID = SessionDashboardViewModel.defaultCoachProfileId) {
        self.session = session
        self.container = container
        self.coachProfileId = coachProfileId
        self.latencyMonitor = container.latencyMonitor
        loadConfig()
        Task { await refresh() }
    }

    func refresh() async {
        await loadAthletes()
        await loadSensors()
        await loadSnapshots()
        await loadMarkers()
        await loadMappings()
        if selectedSnapshot == nil {
            selectedSnapshot = snapshots.first
        }
    }

    func select(snapshot: AthleteSnapshot, metric: CoachMetric) {
        selectedSnapshot = snapshot
        selectedMetric = metric
    }

    func displayData(for snapshot: AthleteSnapshot, metric: CoachMetric) -> MetricDisplayData {
        switch metric {
        case .heartRate:
            let value = snapshot.currentBpm.map { "\($0)" } ?? "--"
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: metric.unit,
                                     trendDelta: snapshot.trendDelta,
                                     zoneFraction: snapshot.zoneFraction)
        case .averageHeartRate:
            let value = snapshot.averageBpm.map { String(format: "%.0f", $0) } ?? "--"
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: metric.unit,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        case .maxHeartRate:
            let value = snapshot.maxBpm.map { "\($0)" } ?? "--"
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: metric.unit,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        case .minHeartRate:
            let value = snapshot.minBpm.map { "\($0)" } ?? "--"
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: metric.unit,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        case .zoneFraction:
            let percent = snapshot.zoneFraction.map { Int(round($0 * 100)) }
            let value = percent.map { "\($0)%" } ?? "--"
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: nil,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        case .timeInZone:
            let minutes = snapshot.totalZoneSeconds / 60
            let value = String(format: "%.1f", minutes)
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: metric.unit,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        case .recovery:
            let recovery = recoverySeconds(for: snapshot)
            let value = recovery.map { String(format: "%.0f", $0) } ?? "--"
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: metric.unit,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        case .trainingLoad:
            let load = snapshot.averageBpm ?? 0
            let relative = snapshot.zoneFraction ?? 0
            let value = String(format: "%.0f", load * (1 + relative))
            return MetricDisplayData(title: metric.displayName,
                                     value: value,
                                     unit: nil,
                                     trendDelta: nil,
                                     zoneFraction: snapshot.zoneFraction)
        }
    }

    func metricsForBoard() -> [CoachMetric] {
        let metrics = visibleMetrics.isEmpty ? CoachMetric.defaults : visibleMetrics
        if metrics.count >= layout.tileCount {
            return Array(metrics.prefix(layout.tileCount))
        }
        var repeated = metrics
        while repeated.count < layout.tileCount {
            repeated.append(contentsOf: metrics)
        }
        return Array(repeated.prefix(layout.tileCount))
    }

    func zoneBreakpoints() -> [Double] {
        let keys = ["zone1", "zone2", "zone3", "zone4"]
        return keys.compactMap { zoneThresholds[$0] }.sorted()
    }

    func zoneFractionColorStops() -> [Double] {
        let stops = zoneBreakpoints()
        if stops.isEmpty { return [0.6, 0.7, 0.8, 0.9] }
        return stops
    }

    func currentZone(for snapshot: AthleteSnapshot) -> Int? {
        guard let fraction = snapshot.zoneFraction else { return nil }
        let thresholds = zoneFractionColorStops()
        for (index, breakpoint) in thresholds.enumerated() {
            if fraction < breakpoint { return index }
        }
        return thresholds.count
    }

    func markInterval(for snapshot: AthleteSnapshot?) {
        let markerInput = EventInput(sessionId: session.id,
                                     athleteId: snapshot?.id,
                                     type: "interval",
                                     start: Date())
        do {
            try container.eventRepository.upsert(markerInput)
            Task { await loadMarkers() }
        } catch {
            errorMessage = "Intervall konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    func removeMappings(at offsets: IndexSet) {
        let records = offsets.compactMap { index in
            mappings[index]
        }
        do {
            let stored = try container.mappingRepository.fetchAll()
            let toDelete = stored.filter { mapping in records.contains { $0.id == mapping.id } }
            try container.mappingRepository.deleteMappings(toDelete)
            Task { await loadMappings() }
        } catch {
            errorMessage = "Mappings konnten nicht gelöscht werden: \(error.localizedDescription)"
        }
    }

    func upsertMapping(athleteId: UUID, sensorId: UUID, nickname: String?) {
        let input = MappingInput(athleteId: athleteId, sensorId: sensorId, nickname: nickname)
        do {
            try container.mappingRepository.upsert(input)
            Task { await loadMappings() }
        } catch {
            errorMessage = "Mapping fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func persistConfig() {
        var thresholds = zoneThresholds
        if let index = BoardLayout.allCases.firstIndex(of: layout) {
            thresholds["layoutIndex"] = Double(index)
        }
        let metricsRaw = visibleMetrics.map(\.rawValue)
        let input = MetricConfigInput(coachProfileId: coachProfileId,
                                      visibleMetrics: metricsRaw,
                                      thresholds: thresholds)
        do {
            try container.metricConfigRepository.upsert(input)
        } catch {
            errorMessage = "Konfiguration konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    func toggleMetric(_ metric: CoachMetric) {
        if visibleMetrics.contains(metric) {
            visibleMetrics.removeAll { $0 == metric }
        } else {
            visibleMetrics.append(metric)
        }
    }

    @discardableResult
    func exportData(format: DataExportFormat) async -> URL? {
        guard !isExporting else { return nil }
        errorMessage = nil
        isExporting = true
        exportProgress = DataExportProgress(stage: .preparing, processedItems: 0, totalItems: 0)

        defer { isExporting = false }

        do {
            let url = try await container.exportService.export(
                format: format,
                progress: { [weak self] progress in
                    guard let self else { return }
                    Task { @MainActor in
                        self.exportProgress = progress
                    }
                },
                completion: nil
            )
            lastExportURL = url
            exportProgress = nil
            return url
        } catch {
            exportProgress = nil
            lastExportURL = nil
            errorMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }

    func updateLayout(_ layout: BoardLayout) {
        self.layout = layout
    }

    func updateThreshold(key: String, value: Double) {
        zoneThresholds[key] = value
    }

    func recoverySeconds(for snapshot: AthleteSnapshot) -> TimeInterval? {
        let relevantMarkers = intervalMarkers.filter { marker in
            marker.athleteId == snapshot.id || marker.athleteId == nil
        }
        guard let lastMarker = relevantMarkers.sorted(by: { $0.timestamp < $1.timestamp }).last else {
            return nil
        }
        return Date().timeIntervalSince(lastMarker.timestamp)
    }

    func markersForAthlete(_ athlete: AthleteSnapshot?) -> [IntervalMarker] {
        guard let athlete else { return intervalMarkers }
        return intervalMarkers.filter { $0.athleteId == athlete.id || $0.athleteId == nil }
    }

    func layoutIndex() -> Int {
        BoardLayout.allCases.firstIndex(of: layout) ?? 0
    }

    private func loadConfig() {
        do {
            let configs = try container.metricConfigRepository.fetchConfigs(for: coachProfileId)
            if let config = configs.first {
                let metrics = config.visibleMetrics.compactMap(CoachMetric.init(rawValue:))
                if !metrics.isEmpty {
                    visibleMetrics = metrics
                }
                var thresholds = config.thresholds
                if let index = thresholds["layoutIndex"], index >= 0 {
                    let layout = BoardLayout.layout(for: Int(index))
                    self.layout = layout
                }
                thresholds.removeValue(forKey: "layoutIndex")
                if !thresholds.isEmpty {
                    zoneThresholds = thresholds
                }
            }
        } catch {
            errorMessage = "Konfiguration konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }

    private func loadAthletes() async {
        do {
            let athletes = try container.athleteRepository.fetchAll()
            self.athletes = athletes
        } catch {
            errorMessage = "Athleten konnten nicht geladen werden: \(error.localizedDescription)"
            self.athletes = []
        }
    }

    private func loadSensors() async {
        do {
            let sensors = try container.sensorRepository.fetchAll()
            self.sensors = sensors
        } catch {
            errorMessage = "Sensoren konnten nicht geladen werden: \(error.localizedDescription)"
            self.sensors = []
        }
    }

    private func loadSnapshots() async {
        do {
            let samples = try container.hrSampleRepository.fetchSamples(sessionId: session.id)
            let grouped = Dictionary(grouping: samples, by: \.athleteId)
            let snapshots = athletes.map { athlete in
                let athleteSamples = grouped[athlete.id] ?? []
                return makeSnapshot(for: athlete, samples: athleteSamples)
            }
            for snapshot in snapshots {
                if let timestamp = snapshot.lastUpdated {
                    let latency = Date().timeIntervalSince(timestamp)
                    latencyMonitor.recordLatency(streamId: snapshot.id,
                                                 label: snapshot.name,
                                                 sampleTimestamp: timestamp,
                                                 latency: latency)
                }
            }
            self.snapshots = snapshots
        } catch {
            errorMessage = "Metriken konnten nicht geladen werden: \(error.localizedDescription)"
            self.snapshots = []
        }
    }

    private func makeSnapshot(for athlete: AthleteRecord, samples: [HRSampleRecord]) -> AthleteSnapshot {
        let sortedSamples = samples.sorted(by: { $0.timestamp < $1.timestamp })
        let current = sortedSamples.last
        let previous = sortedSamples.dropLast().last
        let currentBpm = current.map { Int($0.heartRate) }
        let average: Double?
        if sortedSamples.isEmpty {
            average = nil
        } else {
            let sum = sortedSamples.reduce(0) { $0 + Int($1.heartRate) }
            average = Double(sum) / Double(sortedSamples.count)
        }
        let maxBpm = sortedSamples.map { Int($0.heartRate) }.max()
        let minBpm = sortedSamples.map { Int($0.heartRate) }.min()
        let trendDelta: Int?
        if let current = current, let previous = previous {
            trendDelta = Int(current.heartRate) - Int(previous.heartRate)
        } else {
            trendDelta = nil
        }
        let zoneFraction: Double?
        if let currentBpm = currentBpm, athlete.hfMax > 0 {
            zoneFraction = Double(currentBpm) / Double(athlete.hfMax)
        } else {
            zoneFraction = nil
        }
        let totalSeconds: TimeInterval
        if sortedSamples.count < 2 {
            totalSeconds = 0
        } else {
            let first = sortedSamples.first!
            let last = sortedSamples.last!
            totalSeconds = last.timestamp.timeIntervalSince(first.timestamp)
        }
        return AthleteSnapshot(id: athlete.id,
                               name: athlete.name,
                               maxHr: Int(athlete.hfMax),
                               samples: sortedSamples,
                               currentBpm: currentBpm,
                               averageBpm: average,
                               maxBpm: maxBpm,
                               minBpm: minBpm,
                               lastUpdated: current?.timestamp,
                               trendDelta: trendDelta,
                               zoneFraction: zoneFraction,
                               totalZoneSeconds: totalSeconds)
    }

    private func loadMarkers() async {
        do {
            let events = try container.eventRepository.fetchEvents(sessionId: session.id)
            self.intervalMarkers = events.map { IntervalMarker(id: $0.id, timestamp: $0.start, athleteId: $0.athleteId) }
        } catch {
            errorMessage = "Intervalle konnten nicht geladen werden: \(error.localizedDescription)"
            self.intervalMarkers = []
        }
    }

    private func loadMappings() async {
        do {
            let mappings = try container.mappingRepository.fetchAll()
            let displays = mappings.map { record in
                let athleteName = athletes.first(where: { $0.id == record.athleteId })?.name ?? "Unbekannt"
                let sensorName = sensors.first(where: { $0.id == record.sensorId })?.vendor ?? "Sensor"
                let label = sensorLabel(for: record.sensorId, base: sensorName)
                return MappingDisplay(id: record.id,
                                      athleteId: record.athleteId,
                                      athleteName: athleteName,
                                      sensorId: record.sensorId,
                                      sensorLabel: label,
                                      since: record.since,
                                      nickname: record.nickname)
            }
            self.mappings = displays.sorted { $0.since > $1.since }
        } catch {
            errorMessage = "Mappings konnten nicht geladen werden: \(error.localizedDescription)"
            self.mappings = []
        }
    }

    private func sensorLabel(for sensorId: UUID, base: String) -> String {
        guard let sensor = sensors.first(where: { $0.id == sensorId }) else { return base }
        let suffix = sensor.id.uuidString.split(separator: "-").last ?? ""
        return "\(base) · \(suffix)"
    }

    private static let defaultCoachProfileId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let defaultZoneThresholds: [String: Double] = [
        "zone1": 0.6,
        "zone2": 0.7,
        "zone3": 0.8,
        "zone4": 0.9
    ]
}
