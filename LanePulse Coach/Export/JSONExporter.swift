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
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func makeJSON<T: Encodable>(from value: T) throws -> Data {
        try encoder.encode(value)
    }

    func makeWriter(url: URL) throws -> JSONObjectStreamWriter {
        try JSONObjectStreamWriter(url: url, encoder: encoder)
    }
}

struct JSONObjectStreamWriter {
    fileprivate let handle: FileHandle
    fileprivate let encoder: JSONEncoder
    fileprivate var isFirstKey = true
    fileprivate var isClosed = false

    init(url: URL, encoder: JSONEncoder) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        self.handle = try FileHandle(forWritingTo: url)
        self.encoder = encoder
        if let start = "{".data(using: .utf8) {
            handle.write(start)
        }
    }

    mutating func writeArray<Element: Encodable>(key: String,
                                                  body: (inout JSONArrayStreamWriter) throws -> Void) throws {
        guard !isClosed else { return }
        if isFirstKey {
            isFirstKey = false
        } else if let comma = ",".data(using: .utf8) {
            handle.write(comma)
        }
        let keyString = "\"\(key)\":["
        if let keyData = keyString.data(using: .utf8) {
            handle.write(keyData)
        }
        var arrayWriter = JSONArrayStreamWriter(handle: handle, encoder: encoder)
        try body(&arrayWriter)
        try arrayWriter.finish()
    }

    mutating func finish() throws {
        guard !isClosed else { return }
        if let end = "}".data(using: .utf8) {
            handle.write(end)
        }
        try handle.close()
        isClosed = true
    }
}

struct JSONArrayStreamWriter {
    private let handle: FileHandle
    private let encoder: JSONEncoder
    private var isFirstElement = true
    private var isFinished = false

    init(handle: FileHandle, encoder: JSONEncoder) {
        self.handle = handle
        self.encoder = encoder
    }

    mutating func append<Element: Encodable>(_ value: Element) throws {
        guard !isFinished else { return }
        let data = try encoder.encode(value)
        if isFirstElement {
            isFirstElement = false
        } else if let comma = ",".data(using: .utf8) {
            handle.write(comma)
        }
        handle.write(data)
    }

    mutating func append<S: Sequence>(contentsOf sequence: S) throws where S.Element: Encodable {
        for element in sequence {
            try append(element)
        }
    }

    fileprivate mutating func finish() throws {
        guard !isFinished else { return }
        if let end = "]".data(using: .utf8) {
            handle.write(end)
        }
        isFinished = true
    }
}
