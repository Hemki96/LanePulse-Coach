//
//  HRSampleRepository.swift
//  LanePulse Coach
//
//  Handles batch persistence for heart-rate samples (1 Hz).
//

import Foundation
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct HRSampleInput {
    let id: UUID
    let sessionId: UUID
    let athleteId: UUID
    let timestamp: Date
    let heartRate: Int

    init(id: UUID = UUID(),
         sessionId: UUID,
         athleteId: UUID,
         timestamp: Date,
         heartRate: Int) {
        self.id = id
        self.sessionId = sessionId
        self.athleteId = athleteId
        self.timestamp = timestamp
        self.heartRate = heartRate
    }
}

protocol HRSampleRepositoryProtocol {
    func startSession(id: UUID)
    func endSession()
    func sceneDidEnterBackground()
    func enqueue(_ sample: HRSampleInput)
    func enqueue(_ samples: [HRSampleInput])
    func flush() throws
    func fetchSamples(sessionId: UUID?) throws -> [HRSampleRecord]
}

final class HRSampleRepository: HRSampleRepositoryProtocol {
    private let writeContext: NSManagedObjectContext
    private let readContext: NSManagedObjectContext
    private let logger: Logging
    private let batchInterval: TimeInterval
    private let maxBatchSize: Int
    private let pendingStore: PendingHRSampleStoring
    private let notificationCenter: NotificationCenter
    private let sceneDidEnterBackgroundNotification: Notification.Name

    private var buffer: [HRSampleInput] = []
    private let bufferQueue = DispatchQueue(label: "com.lanepulse.coach.hrSampleBuffer")
    private var timer: DispatchSourceTimer?
    private var activeSessionId: UUID?
    private var lastSampleTimestamp: Date?
    private var sceneObserver: NSObjectProtocol?
    private var isFlushing: Bool = false
    private let flushGroup = DispatchGroup()

    init(writeContext: NSManagedObjectContext,
         readContext: NSManagedObjectContext,
         logger: Logging,
         batchInterval: TimeInterval = 1.0,
         maxBatchSize: Int = 120,
         pendingStore: PendingHRSampleStoring? = nil,
         notificationCenter: NotificationCenter = .default,
         sceneDidEnterBackgroundNotification: Notification.Name = HRSampleRepository.defaultSceneDidEnterBackgroundNotification()) {
        self.writeContext = writeContext
        self.readContext = readContext
        self.logger = logger
        self.batchInterval = batchInterval
        self.maxBatchSize = maxBatchSize
        self.pendingStore = pendingStore ?? FileBackedPendingHRSampleStore(logger: logger)
        self.notificationCenter = notificationCenter
        self.sceneDidEnterBackgroundNotification = sceneDidEnterBackgroundNotification
        self.sceneObserver = notificationCenter.addObserver(forName: sceneDidEnterBackgroundNotification,
                                                            object: nil,
                                                            queue: nil) { [weak self] _ in
            self?.sceneDidEnterBackground()
        }
        startTimer()
        flushAsync(force: true)
    }

    deinit {
        if let sceneObserver {
            notificationCenter.removeObserver(sceneObserver)
        }
        timer?.cancel()
        try? flush()
    }

    func startSession(id: UUID) {
        bufferQueue.async { [weak self] in
            guard let self else { return }
            if self.activeSessionId != id {
                self.buffer.removeAll(keepingCapacity: true)
                self.lastSampleTimestamp = nil
            }
            self.activeSessionId = id
        }
    }

    func endSession() {
        do {
            try flush()
        } catch {
            logger.log(level: .error, message: "Failed to flush HR samples when ending session: \(error.localizedDescription)")
        }
        bufferQueue.async { [weak self] in
            guard let self else { return }
            self.activeSessionId = nil
            self.lastSampleTimestamp = nil
        }
    }

    func sceneDidEnterBackground() {
        do {
            try flush()
        } catch {
            logger.log(level: .error, message: "Failed to flush HR samples on background transition: \(error.localizedDescription)")
        }
    }

    func enqueue(_ sample: HRSampleInput) {
        enqueue([sample])
    }

    func enqueue(_ samples: [HRSampleInput]) {
        guard !samples.isEmpty else { return }
        bufferQueue.async { [weak self] in
            guard let self else { return }
            guard let activeSessionId = self.activeSessionId else {
                self.logger.log(level: .warning, message: "Received HR samples without an active session; discarding batch")
                return
            }
            let filtered = samples.filter { $0.sessionId == activeSessionId }
            let mismatched = samples.count - filtered.count
            if mismatched > 0 {
                self.logger.log(level: .warning, message: "Received HR samples for inactive session; discarding \(mismatched) items")
            }
            guard !filtered.isEmpty else { return }
            for sample in filtered {
                if let lastSampleTimestamp, sample.timestamp < lastSampleTimestamp {
                    self.logger.log(level: .warning, message: "Out-of-order HR sample detected; resetting buffer")
                    self.buffer.removeAll(keepingCapacity: true)
                    self.lastSampleTimestamp = nil
                }
                self.lastSampleTimestamp = sample.timestamp
            }
            self.buffer.append(contentsOf: filtered)
            if self.buffer.count >= self.maxBatchSize {
                self.flushAsync()
            }
        }
    }

    func flush() throws {
        flushGroup.wait()
        let drained = bufferQueue.sync { () -> [HRSampleInput] in
            self.isFlushing = true
            let flushed = buffer
            buffer.removeAll(keepingCapacity: true)
            return flushed
        }
        let pendingSamples: [HRSampleInput]
        do {
            pendingSamples = try pendingStore.load()
        } catch {
            logger.log(level: .error, message: "Failed to read pending HR samples: \(error.localizedDescription)")
            pendingSamples = []
        }
        let samples = pendingSamples + drained
        guard !samples.isEmpty else {
            bufferQueue.sync {
                self.isFlushing = false
            }
            return
        }
        flushGroup.enter()
        do {
            try writeContext.performAndWait {
                try persistUnsafe(samples: samples)
            }
        } catch {
            do {
                try pendingStore.store(samples)
            } catch {
                logger.log(level: .error, message: "Failed to persist HR samples fallback: \(error.localizedDescription)")
            }
            bufferQueue.sync {
                self.isFlushing = false
                self.flushGroup.leave()
            }
            throw error
        }
        do {
            try pendingStore.store([])
        } catch {
            logger.log(level: .error, message: "Failed to clear pending HR samples: \(error.localizedDescription)")
        }
        bufferQueue.sync {
            self.isFlushing = false
            self.flushGroup.leave()
        }
    }

    func fetchSamples(sessionId: UUID?) throws -> [HRSampleRecord] {
        let request: NSFetchRequest<HRSampleRecord> = HRSampleRecord.fetchRequest()
        if let sessionId {
            request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HRSampleRecord.timestamp, ascending: true)]
        return try readContext.fetch(request)
    }

    private func flushAsync(force: Bool = false) {
        bufferQueue.async { [weak self] in
            guard let self else { return }
            if !force, self.activeSessionId == nil {
                return
            }
            if self.isFlushing {
                return
            }
            self.isFlushing = true
            let bufferedSamples = self.buffer
            self.buffer.removeAll(keepingCapacity: true)
            let pendingSamples: [HRSampleInput]
            do {
                pendingSamples = try self.pendingStore.load()
            } catch {
                self.logger.log(level: .error, message: "Failed to read pending HR samples: \(error.localizedDescription)")
                pendingSamples = []
            }
            let samples = pendingSamples + bufferedSamples
            guard !samples.isEmpty else {
                self.isFlushing = false
                return
            }
            self.flushGroup.enter()
            let flushGroup = self.flushGroup
            let bufferQueue = self.bufferQueue
            let pendingStore = self.pendingStore
            let logger = self.logger
            let writeContext = self.writeContext
            writeContext.perform { [weak self] in
                guard let self else {
                    bufferQueue.async {
                        flushGroup.leave()
                    }
                    return
                }
                do {
                    try self.persistUnsafe(samples: samples)
                } catch {
                    do {
                        try pendingStore.store(samples)
                    } catch {
                        logger.log(level: .error, message: "Failed to persist HR samples fallback: \(error.localizedDescription)")
                    }
                    logger.log(level: .error, message: "Failed to persist HR samples: \(error.localizedDescription)")
                    bufferQueue.async {
                        self.isFlushing = false
                        flushGroup.leave()
                    }
                    return
                }
                do {
                    try pendingStore.store([])
                } catch {
                    logger.log(level: .error, message: "Failed to clear pending HR samples: \(error.localizedDescription)")
                }
                bufferQueue.async {
                    self.isFlushing = false
                    flushGroup.leave()
                }
            }
        }
    }

    private func persistUnsafe(samples: [HRSampleInput]) throws {
        guard !samples.isEmpty else { return }
        samples.forEach { sample in
            let record = HRSampleRecord(context: writeContext)
            record.id = sample.id
            record.sessionId = sample.sessionId
            record.athleteId = sample.athleteId
            record.timestamp = sample.timestamp
            record.heartRate = Int16(sample.heartRate)
        }
        if writeContext.hasChanges {
            try writeContext.save()
            logger.log(level: .debug, message: "Persisted \(samples.count) HR samples")
        }
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: bufferQueue)
        timer.schedule(deadline: .now() + batchInterval, repeating: batchInterval)
        timer.setEventHandler { [weak self] in
            self?.flushAsync()
        }
        timer.resume()
        self.timer = timer
    }

    private static func defaultSceneDidEnterBackgroundNotification() -> Notification.Name {
#if canImport(UIKit)
        return UIScene.didEnterBackgroundNotification
#else
        return Notification.Name("SceneDidEnterBackgroundNotification")
#endif
    }
}

extension HRSampleInput: Codable { }

extension HRSampleInput: Equatable { }
