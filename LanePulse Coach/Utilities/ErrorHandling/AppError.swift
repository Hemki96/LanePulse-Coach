//
//  AppError.swift
//  LanePulse Coach
//
//  Centralized application error definitions.
//

import Foundation

enum AppError: LocalizedError {
    case bluetoothUnavailable
    case dataUnavailable
    case exportFailed(reason: String)
    case analyticsFailure(reason: String)

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return String(localized: "Bluetooth is currently unavailable.")
        case .dataUnavailable:
            return String(localized: "Requested data could not be located.")
        case .exportFailed(let reason):
            return String(localized: "Data export failed: \(reason)")
        case .analyticsFailure(let reason):
            return String(localized: "Analytics tracking failed: \(reason)")
        }
    }
}
