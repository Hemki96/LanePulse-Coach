//
//  LanePulse_CoachApp.swift
//  LanePulse Coach
//

import SwiftUI
import CoreData

@main
struct LanePulse_CoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container: AppContainer

    init() {
        let resolvedContainer: AppContainer
        if ProcessInfo.processInfo.arguments.contains("--uitest-multi-stream") {
            resolvedContainer = AppContainer.makeUITestMultiStream()
        } else {
            resolvedContainer = AppContainer.makeDefault()
        }
        _container = StateObject(wrappedValue: resolvedContainer)
        appDelegate.containerProvider = { resolvedContainer }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
                .environmentObject(container)
        }
    }
}
