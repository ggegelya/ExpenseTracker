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
    let container: DependencyContainer
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var accountsViewModel: AccountsViewModel
    @StateObject private var pendingViewModel: PendingTransactionsViewModel
    
    @State private var selectedTab = 0
    @State private var showPendingBadge = false
    init() {
        // Setup dependency container
        self.container = DependencyContainer.shared
        
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
            MainTabView(
                selectedTab: $selectedTab,
                showPendingBadge: $showPendingBadge
            )
            .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
            .environmentObject(transactionViewModel)
            .environmentObject(accountsViewModel)
            .environmentObject(pendingViewModel)
            .onAppear {
                checkPendingTransactions()
            }
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
    
    private func checkPendingTransactions() {
        Task {
            await pendingViewModel.loadPendingTransactions()
            showPendingBadge = !pendingViewModel.pendingTransactions.isEmpty
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int
    @Binding var showPendingBadge: Bool
    @EnvironmentObject var pendingViewModel: PendingTransactionsViewModel
    
    var body: some View {
        TabView(selection: $selectedTab) {
            QuickEntryView()
                .tabItem {
                    Label("Додати", systemImage: "plus.circle.fill")
                }
                .tag(0)
            
            TransactionListView()
                .tabItem {
                    Label("Транзакції", systemImage: "list.bullet")
                }
                .tag(1)
            
            PendingTransactionsView()
                .tabItem {
                    Label("Очікує", systemImage: "clock.fill")
                }
                .badge(pendingViewModel.pendingTransactions.count)
                .tag(2)
            
            AccountsView()
                .tabItem {
                    Label("Рахунки", systemImage: "creditcard.fill")
                }
                .tag(3)
            
            AnalyticsView()
                .tabItem {
                    Label("Аналітика", systemImage: "chart.pie.fill")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
   MainTabView(
       selectedTab: .constant(0),
       showPendingBadge: .constant(false)
   )
   .environmentObject(DependencyContainer.preview.makeTransactionViewModel())
   .environmentObject(DependencyContainer.preview.makeAccountsViewModel())
   .environmentObject(DependencyContainer.preview.makePendingTransactionsViewModel())
   .environment(\.managedObjectContext, DependencyContainer.preview.persistenceController.container.viewContext)
}
