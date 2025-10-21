//
//  ExpenseTrackerApp.swift
//
//  Created by Heorhii Hehelia on 14.08.2025.
//

import SwiftUI

@main
struct ExpenseTrackerApp: App {
    let persistenceController = PersistenceController.shared
    let container: DependencyContainer
    
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var accountsViewModel: AccountsViewModel
    @StateObject private var pendingViewModel: PendingTransactionsViewModel
    
    @State private var selectedTab = 0
    @State private var showPendingBadge = false
    
    init() {
        // Setup dependency container
#if DEBUG
        self.container = DependencyContainer(environment: .staging)
#else
        self.container = DependencyContainer(environment: .production)
#endif
        
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
}





#Preview {
    let previewContainer = DependencyContainer.makeForPreviews()
    return MainTabView(container: previewContainer)
        .environmentObject(previewContainer.makeTransactionViewModel())
        .environmentObject(previewContainer.makeAccountsViewModel())
        .environmentObject(previewContainer.makePendingTransactionsViewModel())
        .environment(\.managedObjectContext, previewContainer.persistenceController.container.viewContext)
}
