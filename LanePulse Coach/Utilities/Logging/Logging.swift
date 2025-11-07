//
//  Logging.swift
//  LanePulse Coach
//
//  Shared logging abstractions for the project.
//

import Foundation

enum LogLevel: String {
    case debug
    case info
    case warning
    case error
}

protocol Logging {
    func log(level: LogLevel, message: String, metadata: [String: String]?)
}

extension Logging {
    func log(level: LogLevel = .info, message: String) {
        log(level: level, message: message, metadata: nil)
    }

    func log(level: LogLevel = .info, message: String, metadata: [String: String]) {
        log(level: level, message: message, metadata: metadata)
    }
}

final class AppLogger: Logging {
    private let subsystem: String
    private let dateFormatter: ISO8601DateFormatter

    init(subsystem: String = "com.lanepulse.coach") {
        self.subsystem = subsystem
        self.dateFormatter = ISO8601DateFormatter()
    }

    func log(level: LogLevel, message: String, metadata: [String: String]?) {
        var output = "[\(dateFormatter.string(from: Date()))][\(subsystem)][\(level.rawValue.uppercased())] \(message)"
        if let metadata, !metadata.isEmpty {
            let metaDescription = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            output.append(" {\(metaDescription)}")
        }
        print(output)
    }
}
