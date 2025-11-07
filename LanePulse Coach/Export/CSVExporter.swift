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
            T.csvHeaders.map { escapeCSV(model.csvRow[$0] ?? "") }.joined(separator: ",")
        }
        return ([headerLine] + rows).joined(separator: "\n")
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
