//
//  SessionListViewModel.swift
//  LanePulse Coach
//
//  Created to manage session list fetching, mutations, and scan state.
//

import Foundation
import CoreData
import Combine

@MainActor
final class SessionListViewModel: NSObject, ObservableObject {
    struct Snapshot: Equatable {
        struct Item: Identifiable, Equatable {
            let objectID: NSManagedObjectID
            let sessionID: UUID
            let startDate: Date
            let laneGroup: String?

            var id: NSManagedObjectID { objectID }
        }

        var items: [Item]

        static let empty = Snapshot(items: [])
    }

    @Published private(set) var snapshot: Snapshot
    @Published private(set) var isScanning: Bool

    private let sessionRepository: SessionRepositoryProtocol
    private let bleManager: BLEManaging
    private let analyticsService: AnalyticsServicing
    private let logger: Logging
    private let context: NSManagedObjectContext
    private let widgetRefresher: WidgetRefreshing?
    private var fetchedResultsController: NSFetchedResultsController<SessionRecord>!
    private var scanningCancellable: AnyCancellable?

    init(sessionRepository: SessionRepositoryProtocol,
         bleManager: BLEManaging,
         analyticsService: AnalyticsServicing,
         logger: Logging,
         context: NSManagedObjectContext,
         widgetRefresher: WidgetRefreshing? = nil) {
        self.sessionRepository = sessionRepository
        self.bleManager = bleManager
        self.analyticsService = analyticsService
        self.logger = logger
        self.context = context
        self.widgetRefresher = widgetRefresher
        self.snapshot = .empty
        self.isScanning = bleManager.isScanning
        logger.log(level: .debug, message: "SessionListViewModel initialized. Initial scanning state: \(bleManager.isScanning)")
        super.init()
        configureFetchedResultsController()
        bindScanningUpdates()
    }

    convenience init(container: AppContainer) {
        self.init(sessionRepository: container.sessionRepository,
                  bleManager: container.bleManager,
                  analyticsService: container.analyticsService,
                  logger: container.logger,
                  context: container.persistenceController.container.viewContext,
                  widgetRefresher: container.widgetRefresher)
    }

    func addSession() {
        logger.log(level: .debug, message: "Attempting to add a new session")
        do {
            let record = try sessionRepository.createSession(SessionInput())
            logger.log(level: .info, message: "Session successfully created", metadata: ["sessionID": record.id.uuidString])
            analyticsService.track(event: AnalyticsEvent(name: "session_created"))
            widgetRefresher?.reloadAll()
        } catch {
            logger.log(level: .error, message: "Failed to add session: \(error.localizedDescription)")
        }
    }

    func deleteSessions(at offsets: IndexSet) {
        logger.log(level: .debug, message: "Deleting sessions at offsets: \(offsets.map(String.init).joined(separator: ","))")
        let items = offsets.compactMap { index in
            snapshot.items[safe: index]
        }

        let records: [SessionRecord] = items.compactMap { item in
            session(for: item.objectID)
        }

        guard !records.isEmpty else { return }

        do {
            try sessionRepository.deleteSessions(records)
            logger.log(level: .info,
                       message: "Deleted sessions",
                       metadata: ["count": "\(records.count)",
                                  "sessionIDs": records.map { $0.id.uuidString }.joined(separator: ",")])
            analyticsService.track(event: AnalyticsEvent(name: "session_deleted",
                                                          metadata: ["count": "\(records.count)"]))
            widgetRefresher?.reloadAll()
        } catch {
            logger.log(level: .error, message: "Failed to delete sessions: \(error.localizedDescription)")
        }
    }

    func toggleScanning() {
        logger.log(level: .debug, message: "Toggling scanning. Current state: \(bleManager.isScanning)")
        if bleManager.isScanning {
            bleManager.stopScanning()
            logger.log(level: .info, message: "Requested BLE scan stop")
        } else {
            bleManager.startScanning()
            logger.log(level: .info, message: "Requested BLE scan start")
        }
        isScanning = bleManager.isScanning
        logger.log(level: .debug, message: "Scanning state updated to: \(isScanning)")
    }

    func session(for objectID: NSManagedObjectID) -> SessionRecord? {
        do {
            return try context.existingObject(with: objectID) as? SessionRecord
        } catch {
            logger.log(level: .error, message: "Failed to load session for objectID: \(error.localizedDescription)")
            return nil
        }
    }

    private func configureFetchedResultsController() {
        logger.log(level: .debug, message: "Configuring fetched results controller")
        let request: NSFetchRequest<SessionRecord> = SessionRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionRecord.startDate, ascending: false)]
        request.fetchBatchSize = 50
        let controller = NSFetchedResultsController(fetchRequest: request,
                                                    managedObjectContext: context,
                                                    sectionNameKeyPath: nil,
                                                    cacheName: nil)
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try fetchedResultsController.performFetch()
            logger.log(level: .info, message: "Fetched initial sessions", metadata: ["count": "\(fetchedResultsController.fetchedObjects?.count ?? 0)"])
        } catch {
            logger.log(level: .error, message: "Failed to fetch sessions: \(error.localizedDescription)")
        }
        updateSnapshot()
    }

    private func updateSnapshot() {
        guard let sessions = fetchedResultsController.fetchedObjects else {
            snapshot = .empty
            logger.log(level: .warning, message: "Fetched results controller returned no sessions; snapshot cleared")
            return
        }

        let items = sessions.map { record in
            Snapshot.Item(objectID: record.objectID,
                          sessionID: record.id,
                          startDate: record.startDate,
                          laneGroup: record.laneGroup)
        }

        snapshot = Snapshot(items: items)
        logger.log(level: .debug, message: "Snapshot updated", metadata: ["count": "\(items.count)"])
    }

    private func bindScanningUpdates() {
        guard let publishingManager = bleManager as? BLEScanStatePublishing else {
            logger.log(level: .warning, message: "BLE manager does not publish scan state updates; scanning indicator may become stale")
            return
        }

        scanningCancellable = publishingManager.isScanningPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isScanning in
                guard let self else { return }
                self.logger.log(level: .debug, message: "Received scan state update: \(isScanning)")
                self.isScanning = isScanning
            }
    }
}

extension SessionListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        logger.log(level: .debug, message: "Fetched results controller signalled content change")
        updateSnapshot()
        widgetRefresher?.reloadAll()
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
