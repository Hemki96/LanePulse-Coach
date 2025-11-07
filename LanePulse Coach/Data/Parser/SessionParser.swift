import Foundation

struct SessionMetadata: Equatable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let laneGroup: String?
    let coachNotes: String?
    let athleteIds: [UUID]
}

enum SessionParserError: Error, Equatable {
    case invalidJSON
    case missingField(String)
    case incompleteStream
}

final class SessionParser {
    private let decoder: JSONDecoder
    private var buffer = Data()

    init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func parse(json data: Data) throws -> SessionMetadata {
        let metadata = try decoder.decode(SessionMetadata.self, from: data)
        try validate(metadata)
        return metadata
    }

    func append(jsonChunk: Data) throws -> SessionMetadata? {
        buffer.append(jsonChunk)
        do {
            let object = try JSONSerialization.jsonObject(with: buffer, options: [])
            let normalized = try JSONSerialization.data(withJSONObject: object)
            let metadata = try decoder.decode(SessionMetadata.self, from: normalized)
            try validate(metadata)
            buffer.removeAll(keepingCapacity: false)
            return metadata
        } catch let error as DecodingError {
            buffer.removeAll(keepingCapacity: false)
            switch error {
            case .keyNotFound(let key, _):
                throw SessionParserError.missingField(key.stringValue)
            default:
                throw SessionParserError.invalidJSON
            }
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == 3840 {
                return nil
            }
            buffer.removeAll(keepingCapacity: false)
            throw SessionParserError.invalidJSON
        }
    }

    func finalizeStream() throws {
        guard buffer.isEmpty else {
            buffer.removeAll(keepingCapacity: false)
            throw SessionParserError.incompleteStream
        }
    }

    private func validate(_ metadata: SessionMetadata) throws {
        if metadata.athleteIds.isEmpty {
            throw SessionParserError.missingField("athleteIds")
        }
    }
}
