//
//  HRSampleRepository.swift
//  LanePulse Coach
//
//  Handles batch persistence for heart-rate samples (1 Hz).
//

import Foundation
import CoreData

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

    private var buffer: [HRSampleInput] = []
    private let bufferQueue = DispatchQueue(label: "com.lanepulse.coach.hrSampleBuffer")
    private var timer: DispatchSourceTimer?

    init(writeContext: NSManagedObjectContext,
         readContext: NSManagedObjectContext,
         logger: Logging,
         batchInterval: TimeInterval = 1.0,
         maxBatchSize: Int = 120) {
        self.writeContext = writeContext
        self.readContext = readContext
        self.logger = logger
        self.batchInterval = batchInterval
        self.maxBatchSize = maxBatchSize
        startTimer()
    }

    deinit {
        timer?.cancel()
        try? flush()
    }

    func enqueue(_ sample: HRSampleInput) {
        enqueue([sample])
    }

    func enqueue(_ samples: [HRSampleInput]) {
        guard !samples.isEmpty else { return }
        bufferQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(contentsOf: samples)
            if self.buffer.count >= self.maxBatchSize {
                self.flushAsync()
            }
        }
    }

    func flush() throws {
        let samples = bufferQueue.sync { () -> [HRSampleInput] in
            let flushed = buffer
            buffer.removeAll(keepingCapacity: true)
            return flushed
        }
        try writeContext.performAndWait {
            try persistUnsafe(samples: samples)
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

    private func flushAsync() {
        bufferQueue.async { [weak self] in
            guard let self else { return }
            let samples = self.buffer
            self.buffer.removeAll(keepingCapacity: true)
            guard !samples.isEmpty else { return }
            self.writeContext.perform { [weak self] in
                do {
                    try self?.persistUnsafe(samples: samples)
                } catch {
                    self?.logger.log(level: .error, message: "Failed to persist HR samples: \(error.localizedDescription)")
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
}
