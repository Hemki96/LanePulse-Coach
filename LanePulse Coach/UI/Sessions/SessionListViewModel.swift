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
    private var fetchedResultsController: NSFetchedResultsController<SessionRecord>!
    private var scanningCancellable: AnyCancellable?

    init(sessionRepository: SessionRepositoryProtocol,
         bleManager: BLEManaging,
         analyticsService: AnalyticsServicing,
         logger: Logging,
         context: NSManagedObjectContext) {
        self.sessionRepository = sessionRepository
        self.bleManager = bleManager
        self.analyticsService = analyticsService
        self.logger = logger
        self.context = context
        self.snapshot = .empty
        self.isScanning = bleManager.isScanning
        super.init()
        configureFetchedResultsController()
        bindScanningUpdates()
    }

    convenience init(container: AppContainer) {
        self.init(sessionRepository: container.sessionRepository,
                  bleManager: container.bleManager,
                  analyticsService: container.analyticsService,
                  logger: container.logger,
                  context: container.persistenceController.container.viewContext)
    }

    func addSession() {
        do {
            _ = try sessionRepository.createSession(SessionInput())
            analyticsService.track(event: AnalyticsEvent(name: "session_created"))
        } catch {
            logger.log(level: .error, message: "Failed to add session: \(error.localizedDescription)")
        }
    }

    func deleteSessions(at offsets: IndexSet) {
        let items = offsets.compactMap { index in
            snapshot.items[safe: index]
        }

        let records: [SessionRecord] = items.compactMap { item in
            session(for: item.objectID)
        }

        guard !records.isEmpty else { return }

        do {
            try sessionRepository.deleteSessions(records)
            analyticsService.track(event: AnalyticsEvent(name: "session_deleted",
                                                          metadata: ["count": "\(records.count)"]))
        } catch {
            logger.log(level: .error, message: "Failed to delete sessions: \(error.localizedDescription)")
        }
    }

    func toggleScanning() {
        if bleManager.isScanning {
            bleManager.stopScanning()
        } else {
            bleManager.startScanning()
        }
        isScanning = bleManager.isScanning
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
        let request: NSFetchRequest<SessionRecord> = SessionRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionRecord.startDate, ascending: false)]
        let controller = NSFetchedResultsController(fetchRequest: request,
                                                    managedObjectContext: context,
                                                    sectionNameKeyPath: nil,
                                                    cacheName: nil)
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try fetchedResultsController.performFetch()
        } catch {
            logger.log(level: .error, message: "Failed to fetch sessions: \(error.localizedDescription)")
        }
        updateSnapshot()
    }

    private func updateSnapshot() {
        guard let sessions = fetchedResultsController.fetchedObjects else {
            snapshot = .empty
            return
        }

        let items = sessions.map { record in
            Snapshot.Item(objectID: record.objectID,
                          sessionID: record.id,
                          startDate: record.startDate,
                          laneGroup: record.laneGroup)
        }

        snapshot = Snapshot(items: items)
    }

    private func bindScanningUpdates() {
        guard let observableManager = bleManager as? (BLEManaging & ObservableObject) else { return }
        scanningCancellable = observableManager.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                self.isScanning = self.bleManager.isScanning
            }
    }
}

extension SessionListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateSnapshot()
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
