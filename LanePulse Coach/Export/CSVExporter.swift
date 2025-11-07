//
//  CSVExporter.swift
//  LanePulse Coach
//
//  Lightweight CSV encoder for export DTOs.
//

import Foundation

protocol CSVConvertible {
    static var csvHeaders: [String] { get }
    var csvRow: [String: String] { get }
}

struct CSVExporter {
    func makeCSV<T: CSVConvertible>(from models: [T]) -> String {
        guard !models.isEmpty else {
            return T.csvHeaders.joined(separator: ",")
        }
        let headerLine = T.csvHeaders.joined(separator: ",")
        let rows = models.map { model in
            T.csvHeaders.map { CSVSequenceWriter<T>.escapeCSV(model.csvRow[$0] ?? "") }.joined(separator: ",")
        }
        return ([headerLine] + rows).joined(separator: "\n")
    }

    func makeWriter<T: CSVConvertible>(for type: T.Type, url: URL) throws -> CSVSequenceWriter<T> {
        try CSVSequenceWriter<T>(url: url)
    }
}

struct CSVSequenceWriter<T: CSVConvertible> {
    private let handle: FileHandle
    private var hasWrittenRow = false

    init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        self.handle = try FileHandle(forWritingTo: url)
        let headerLine = T.csvHeaders.joined(separator: ",") + "\n"
        if let data = headerLine.data(using: .utf8) {
            handle.write(data)
        }
    }

    mutating func append(_ value: T) throws {
        let row = T.csvHeaders.map { Self.escapeCSV(value.csvRow[$0] ?? "") }
            .joined(separator: ",")
        if hasWrittenRow {
            if let newline = "\n".data(using: .utf8) {
                handle.write(newline)
            }
        }
        if let data = row.data(using: .utf8) {
            handle.write(data)
        }
        hasWrittenRow = true
    }

    mutating func append<S: Sequence>(contentsOf values: S) throws where S.Element == T {
        for value in values {
            try append(value)
        }
    }

    mutating func finish() throws {
        try handle.close()
    }

    fileprivate static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
