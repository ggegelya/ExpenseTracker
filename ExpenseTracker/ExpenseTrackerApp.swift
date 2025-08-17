//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 14.08.2025.
//

import SwiftUI

@main
struct ExpenseTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            QuickEntryView()
        }
    }
}
