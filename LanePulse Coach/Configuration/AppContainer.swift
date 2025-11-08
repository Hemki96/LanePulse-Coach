//
//  AppContainer.swift
//  LanePulse Coach
//
//  Central dependency container for the application modules.
//

import Foundation
import CoreData
#if canImport(Combine)
import Combine
#endif

final class AppContainer: ObservableObject {
    let logger: Logging
    let persistenceController: PersistenceController
    let athleteRepository: AthleteRepositoryProtocol
    let sensorRepository: SensorRepositoryProtocol
    let mappingRepository: MappingRepositoryProtocol
    let sessionRepository: SessionRepositoryProtocol
    let hrSampleRepository: HRSampleRepositoryProtocol
    let eventRepository: EventRepositoryProtocol
    let metricConfigRepository: MetricConfigRepositoryProtocol
    let bleManager: BLEManaging
    let analyticsService: AnalyticsServicing
    let exportService: DataExporting
    let latencyMonitor: LatencyMonitoring
    let backgroundTaskCoordinator: BackgroundTaskCoordinating
    let notificationManager: NotificationManaging
    let widgetRefresher: WidgetRefreshing

    init(logger: Logging,
         persistenceController: PersistenceController,
         athleteRepository: AthleteRepositoryProtocol,
         sensorRepository: SensorRepositoryProtocol,
         mappingRepository: MappingRepositoryProtocol,
         sessionRepository: SessionRepositoryProtocol,
         hrSampleRepository: HRSampleRepositoryProtocol,
         eventRepository: EventRepositoryProtocol,
         metricConfigRepository: MetricConfigRepositoryProtocol,
         bleManager: BLEManaging,
         analyticsService: AnalyticsServicing,
         exportService: DataExporting,
         latencyMonitor: LatencyMonitoring,
         backgroundTaskCoordinator: BackgroundTaskCoordinating,
         notificationManager: NotificationManaging,
         widgetRefresher: WidgetRefreshing) {
        self.logger = logger
        self.persistenceController = persistenceController
        self.athleteRepository = athleteRepository
        self.sensorRepository = sensorRepository
        self.mappingRepository = mappingRepository
        self.sessionRepository = sessionRepository
        self.hrSampleRepository = hrSampleRepository
        self.eventRepository = eventRepository
        self.metricConfigRepository = metricConfigRepository
        self.bleManager = bleManager
        self.analyticsService = analyticsService
        self.exportService = exportService
        self.latencyMonitor = latencyMonitor
        self.backgroundTaskCoordinator = backgroundTaskCoordinator
        self.notificationManager = notificationManager
        self.widgetRefresher = widgetRefresher
    }

    static func makeDefault() -> AppContainer {
        AppContainerFactory().make(configuration: DefaultAppConfiguration().make())
    }

    static func makePreview() -> AppContainer {
        AppContainerFactory().make(configuration: PreviewConfiguration().make())
    }

    static func makeUITestMultiStream() -> AppContainer {
        AppContainerFactory().make(configuration: UITestConfiguration().make())
    }
}
