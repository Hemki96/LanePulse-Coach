//
//  HRSamplePendingStore.swift
//  LanePulse Coach
//
//  Provides persistent caching for HR samples when CoreData persistence fails.
//

import Foundation

protocol PendingHRSampleStoring {
    func load() throws -> [HRSampleInput]
    func store(_ samples: [HRSampleInput]) throws
}

final class FileBackedPendingHRSampleStore: PendingHRSampleStoring {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.lanepulse.coach.hrPendingStore", qos: .utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger: Logging

    init(fileURL: URL? = nil,
         fileManager: FileManager = .default,
         logger: Logging) {
        self.fileManager = fileManager
        self.logger = logger
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = FileBackedPendingHRSampleStore.defaultURL(fileManager: fileManager)
        }
    }

    func load() throws -> [HRSampleInput] {
        try queue.sync {
            guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
            let data = try Data(contentsOf: fileURL)
            do {
                return try decoder.decode([HRSampleInput].self, from: data)
            } catch {
                logger.log(level: .error, message: "Failed to decode pending HR samples: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func store(_ samples: [HRSampleInput]) throws {
        try queue.sync {
            if samples.isEmpty {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                return
            }
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try encoder.encode(samples)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private static func defaultURL(fileManager: FileManager) -> URL {
#if os(macOS)
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
#else
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
#endif
        return base.appendingPathComponent("PendingHRSamples.json", isDirectory: false)
    }
}
