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
    @StateObject private var dataManager: DataManager
    @StateObject private var transactionViewModel: TransactionViewModel
    init() {
        let context = PersistenceController.shared.container.viewContext
        let manager = DataManager(context: context)
        let viewModel = TransactionViewModel(dataManager: manager)
        
        _dataManager = StateObject(wrappedValue: manager)
        _transactionViewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some Scene {
        WindowGroup {
            QuickEntryView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(dataManager)
                .environmentObject(transactionViewModel)
                .onAppear {
                    // Configure app-wide settings
                    setupAppearance()
                }
        }
    }
    
    private func setupAppearance() {
        
    }
}
