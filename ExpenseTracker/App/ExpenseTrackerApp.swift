//
//  ExpenseTrackerApp.swift
//
//  Created by Heorhii Hehelia on 14.08.2025.
//

import SwiftUI

@MainActor
@main
struct ExpenseTrackerApp: App {
    let container: DependencyContainer

    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var accountsViewModel: AccountsViewModel
    @StateObject private var pendingViewModel: PendingTransactionsViewModel

    @State private var selectedTab = 0
    @State private var showPendingBadge = false

    init() {
        // Disable animations for UI testing
        if TestingConfiguration.shouldDisableAnimations {
            UIView.setAnimationsEnabled(false)
        }

        // Determine environment
        let environment: AppEnvironment
        if TestingConfiguration.isRunningTests {
            environment = .testing
        } else {
#if DEBUG
            environment = .staging
#else
            environment = .production
#endif
        }

        // Setup dependency container
        self.container = DependencyContainer(environment: environment)

        // Reset app state if requested (for UI tests)
        if TestingConfiguration.shouldResetAppState {
            Self.resetAppState()
        }

        // Create view models
        let transactionVM = container.makeTransactionViewModel()
        let accountsVM = container.makeAccountsViewModel()
        let pendingVM = container.makePendingTransactionsViewModel()

        _transactionViewModel = StateObject(wrappedValue: transactionVM)
        _accountsViewModel = StateObject(wrappedValue: accountsVM)
        _pendingViewModel = StateObject(wrappedValue: pendingVM)

        // Setup appearance
        setupAppearance()
    }
    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
                .environmentObject(transactionViewModel)
                .environmentObject(accountsViewModel)
                .environmentObject(pendingViewModel)
                .environmentObject(container.errorHandlingServiceInstance)
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.systemBackground
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private static func resetAppState() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        // Note: Keychain and Core Data clearing should be handled carefully
        // Core Data store deletion is managed by the testing environment (.testing)
        // which uses in-memory store, so no cleanup needed here
    }
}





#Preview {
    let previewContainer = DependencyContainer.makeForPreviews()
    return MainTabView(container: previewContainer)
        .environmentObject(previewContainer.makeTransactionViewModel())
        .environmentObject(previewContainer.makeAccountsViewModel())
        .environmentObject(previewContainer.makePendingTransactionsViewModel())
        .environmentObject(previewContainer.errorHandlingServiceInstance)
        .environment(\.managedObjectContext, previewContainer.persistenceController.container.viewContext)
}
