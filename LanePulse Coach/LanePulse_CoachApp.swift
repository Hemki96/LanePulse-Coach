//
//  LanePulse_CoachApp.swift
//  LanePulse Coach
//

import SwiftUI
import CoreData

@main
struct LanePulse_CoachApp: App {
    @StateObject private var container = AppContainer.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
                .environmentObject(container)
        }
    }
}
