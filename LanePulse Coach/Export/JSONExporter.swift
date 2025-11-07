//
//  JSONExporter.swift
//  LanePulse Coach
//
//  Lightweight JSON encoder for export DTOs.
//

import Foundation

struct JSONExporter {
    private let encoder: JSONEncoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func makeJSON<T: Encodable>(from value: T) throws -> Data {
        try encoder.encode(value)
    }
}
