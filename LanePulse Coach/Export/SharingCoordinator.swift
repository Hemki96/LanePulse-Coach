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
        Task {
            do {
                let url = try await exporter.export(format: format, progress: nil, completion: nil)
                let metadata = SharingMetadata(fileURL: url,
                                               fileName: url.lastPathComponent,
                                               mimeType: format.mimeType,
                                               exportedAt: clock())
                await MainActor.run {
                    presenter.presentShareSheet(with: metadata)
                    completion(.success(metadata))
                }
                logger.log(level: .info, message: "Prepared export for sharing", metadata: ["file": metadata.fileName])
            } catch {
                logger.log(level: .error, message: "Failed to export data: \(error.localizedDescription)")
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
}
