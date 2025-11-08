//
//  BackgroundTaskCoordinator.swift
//  LanePulse Coach
//
//  Coordinates BGTaskScheduler registrations and execution.
//

import Foundation
import BackgroundTasks
import UIKit

protocol BGTaskScheduling {
    func register(forTaskWithIdentifier identifier: String,
                  using queue: DispatchQueue?,
                  launchHandler: @escaping (BGTask) -> Void) -> Bool
    func submit(_ taskRequest: BGTaskRequest) throws
    func cancel(taskRequestWithIdentifier identifier: String)
}

extension BGTaskScheduler: BGTaskScheduling {}

protocol BackgroundTaskCoordinating: AnyObject {
    func registerBackgroundTasks()
    func scheduleAppRefresh()
    func scheduleProcessingTask()
    func handleRemoteNotification(userInfo: [AnyHashable: Any],
                                  completion: @escaping (UIBackgroundFetchResult) -> Void)
    func cancelAll()
}

final class BackgroundTaskCoordinator: BackgroundTaskCoordinating {
    enum Identifier {
        static let processing = "com.lanepulse.coach.background-processing"
        static let refresh = "com.lanepulse.coach.app-refresh"
    }

    private let scheduler: BGTaskScheduling
    private let logger: Logging
    private let hrSampleRepository: HRSampleRepositoryProtocol
    private let widgetRefresher: WidgetRefreshing
    private let queue: DispatchQueue
    private var didRegister: Bool = false

    init(scheduler: BGTaskScheduling = BGTaskScheduler.shared,
         logger: Logging,
         hrSampleRepository: HRSampleRepositoryProtocol,
         widgetRefresher: WidgetRefreshing,
         queue: DispatchQueue = DispatchQueue(label: "com.lanepulse.coach.backgroundtasks", qos: .utility)) {
        self.scheduler = scheduler
        self.logger = logger
        self.hrSampleRepository = hrSampleRepository
        self.widgetRefresher = widgetRefresher
        self.queue = queue
    }

    func registerBackgroundTasks() {
        guard !didRegister else { return }
        didRegister = true
        registerProcessingTask()
        registerRefreshTask()
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Identifier.refresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        submit(request, context: "app refresh")
    }

    func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: Identifier.processing)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        submit(request, context: "data processing")
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any],
                                  completion: @escaping (UIBackgroundFetchResult) -> Void) {
        logger.log(level: .debug, message: "Handling remote notification", metadata: ["payload": "\(userInfo)"])
        scheduleProcessingTask()
        scheduleAppRefresh()
        queue.async { [weak self] in
            guard let self else {
                completion(.failed)
                return
            }
            do {
                try self.hrSampleRepository.flush()
                self.widgetRefresher.reloadAll()
                completion(.newData)
            } catch {
                self.logger.log(level: .error,
                                 message: "Failed to flush samples during remote notification: \(error.localizedDescription)")
                completion(.failed)
            }
        }
    }

    func cancelAll() {
        scheduler.cancel(taskRequestWithIdentifier: Identifier.processing)
        scheduler.cancel(taskRequestWithIdentifier: Identifier.refresh)
    }

    private func registerProcessingTask() {
        let success = scheduler.register(forTaskWithIdentifier: Identifier.processing,
                                         using: queue) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handle(processingTask: processingTask)
        }
        if !success {
            logger.log(level: .error, message: "Failed to register processing background task")
        }
    }

    private func registerRefreshTask() {
        let success = scheduler.register(forTaskWithIdentifier: Identifier.refresh,
                                         using: queue) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handle(refreshTask: refreshTask)
        }
        if !success {
            logger.log(level: .error, message: "Failed to register app refresh background task")
        }
    }

    private func submit(_ request: BGTaskRequest, context: String) {
        do {
            try scheduler.submit(request)
            logger.log(level: .debug, message: "Scheduled \(context) background task")
        } catch {
            logger.log(level: .error, message: "Failed to schedule \(context) background task: \(error.localizedDescription)")
        }
    }

    private func handle(processingTask: BGProcessingTask) {
        logger.log(level: .info, message: "Processing background task began")
        scheduleProcessingTask()
        processingTask.expirationHandler = { [weak self] in
            self?.logger.log(level: .warning, message: "Processing background task expired")
        }
        queue.async { [weak self] in
            guard let self else {
                processingTask.setTaskCompleted(success: false)
                return
            }
            do {
                try self.hrSampleRepository.flush()
                self.widgetRefresher.reloadAll()
                processingTask.setTaskCompleted(success: true)
            } catch {
                self.logger.log(level: .error,
                                 message: "Failed to flush HR samples in processing task: \(error.localizedDescription)")
                processingTask.setTaskCompleted(success: false)
            }
        }
    }

    private func handle(refreshTask: BGAppRefreshTask) {
        logger.log(level: .info, message: "App refresh background task began")
        scheduleAppRefresh()
        refreshTask.expirationHandler = { [weak self] in
            self?.logger.log(level: .warning, message: "App refresh background task expired")
        }
        queue.async { [weak self] in
            guard let self else {
                refreshTask.setTaskCompleted(success: false)
                return
            }
            self.widgetRefresher.reloadAll()
            refreshTask.setTaskCompleted(success: true)
        }
    }
}
