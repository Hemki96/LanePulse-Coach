import XCTest
@testable import LanePulse_Coach

final class ExportTests: XCTestCase {
    func testCSVExporterProducesRowsWithEscaping() {
        struct Athlete: CSVConvertible {
            static let csvHeaders = ["name", "notes"]
            let name: String
            let notes: String

            var csvRow: [String : String] {
                ["name": name, "notes": notes]
            }
        }

        let models = [
            Athlete(name: "Lisa", notes: "New PB"),
            Athlete(name: "Tom", notes: "Needs \"breathing\" focus, lane 3")
        ]

        let csv = CSVExporter().makeCSV(from: models)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "name,notes")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[2].contains("\"Needs \"\"breathing\"\" focus, lane 3\""))
    }

    func testCSVExporterHandlesEmptyInput() {
        struct EmptyModel: CSVConvertible {
            static let csvHeaders = ["id", "value"]
            var csvRow: [String : String] { [:] }
        }

        let csv = CSVExporter().makeCSV(from: [EmptyModel]())
        XCTAssertEqual(csv, "id,value")
    }

    func testSharingCoordinatorSuccessFlow() throws {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("export.csv")
        let exporter = MockExporter(result: fileURL)
        let presenter = MockPresenter()
        let logger = MockLogger()
        let coordinator = SharingCoordinator(exporter: exporter,
                                             presenter: presenter,
                                             logger: logger,
                                             clock: { Date(timeIntervalSince1970: 0) })

        let expectation = XCTestExpectation(description: "completion")
        coordinator.share(format: .csv) { result in
            switch result {
            case .success(let metadata):
                XCTAssertEqual(metadata.fileURL, fileURL)
                XCTAssertEqual(metadata.mimeType, "text/csv")
                XCTAssertEqual(presenter.presentedMetadata, metadata)
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.1)
        XCTAssertEqual(logger.entries.last?.level, .info)
    }

    func testSharingCoordinatorPropagatesError() {
        struct DummyError: Error {}
        let exporter = MockExporter(error: DummyError())
        let presenter = MockPresenter()
        let logger = MockLogger()
        let coordinator = SharingCoordinator(exporter: exporter,
                                             presenter: presenter,
                                             logger: logger)

        let expectation = XCTestExpectation(description: "failure")
        coordinator.share(format: .json) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertTrue(error is DummyError)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.1)
        XCTAssertNil(presenter.presentedMetadata)
        XCTAssertEqual(logger.entries.last?.level, .error)
    }
}

private final class MockExporter: DataExporting {
    private let result: URL?
    private let error: Error?

    init(result: URL) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    func exportData(format: DataExportFormat) throws -> URL {
        if let error { throw error }
        return result ?? URL(fileURLWithPath: "")
    }
}

private final class MockPresenter: SharePresenting {
    private(set) var presentedMetadata: SharingMetadata?

    func presentShareSheet(with metadata: SharingMetadata) {
        presentedMetadata = metadata
    }
}

private final class MockLogger: Logging {
    struct Entry: Equatable {
        let level: LogLevel
        let message: String
    }

    private(set) var entries: [Entry] = []

    func log(level: LogLevel, message: String, metadata: [String : String]?) {
        entries.append(Entry(level: level, message: message))
    }
}
