import Foundation

struct SharingMetadata: Equatable {
    let fileURL: URL
    let fileName: String
    let mimeType: String
    let exportedAt: Date
}

protocol SharePresenting {
    func presentShareSheet(with metadata: SharingMetadata)
}

final class SharingCoordinator {
    private let exporter: DataExporting
    private let presenter: SharePresenting
    private let logger: Logging
    private let clock: () -> Date

    init(exporter: DataExporting,
         presenter: SharePresenting,
         logger: Logging,
         clock: @escaping () -> Date = Date.init) {
        self.exporter = exporter
        self.presenter = presenter
        self.logger = logger
        self.clock = clock
    }

    func share(format: DataExportFormat, completion: @escaping (Result<SharingMetadata, Error>) -> Void) {
        do {
            let url = try exporter.exportData(format: format)
            let metadata = SharingMetadata(fileURL: url,
                                           fileName: url.lastPathComponent,
                                           mimeType: format.mimeType,
                                           exportedAt: clock())
            presenter.presentShareSheet(with: metadata)
            logger.log(level: .info, message: "Prepared export for sharing", metadata: ["file": metadata.fileName])
            completion(.success(metadata))
        } catch {
            logger.log(level: .error, message: "Failed to export data: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
}
