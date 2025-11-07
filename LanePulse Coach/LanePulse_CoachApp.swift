//
//  LanePulse_CoachApp.swift
//  LanePulse Coach
//

import SwiftUI
import CoreData

@main
struct LanePulse_CoachApp: App {
    @StateObject private var container: AppContainer

    init() {
        if ProcessInfo.processInfo.arguments.contains("--uitest-multi-stream") {
            _container = StateObject(wrappedValue: AppContainer.makeUITestMultiStream())
        } else {
            _container = StateObject(wrappedValue: AppContainer.makeDefault())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
                .environmentObject(container)
        }
    }
}
