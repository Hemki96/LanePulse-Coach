//
//  WidgetRefreshController.swift
//  LanePulse Coach
//
//  Provides a thin wrapper around WidgetCenter for targeted reloads.
//

import Foundation
import WidgetKit

protocol WidgetRefreshing: AnyObject {
    func reloadAll()
    func reload(kind: String)
}

final class WidgetRefreshController: WidgetRefreshing {
    private let logger: Logging
    private let supportedKinds: Set<String>

    init(logger: Logging, supportedKinds: Set<String> = []) {
        self.logger = logger
        self.supportedKinds = supportedKinds
    }

    func reloadAll() {
        guard #available(iOS 14.0, *) else { return }
        WidgetCenter.shared.reloadAllTimelines()
        logger.log(level: .debug, message: "Requested widget reload for all kinds")
    }

    func reload(kind: String) {
        guard #available(iOS 14.0, *) else { return }
        if supportedKinds.isEmpty || supportedKinds.contains(kind) {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
            logger.log(level: .debug, message: "Requested widget reload", metadata: ["kind": kind])
        } else {
            logger.log(level: .warning, message: "Attempted to reload unsupported widget kind", metadata: ["kind": kind])
        }
    }
}
