//
//  MainTabView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 07.09.2025.
//


import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case quickEntry = 0
    case transactions
    case pending
    case accounts
    case analytics
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .quickEntry: return "Додати"
        case .transactions: return "Транзакції"
        case .pending: return "Очікують"
        case .accounts: return "Рахунки"
        case .analytics: return "Аналітика"
        }
    }
    
    var icon: String {
        switch self {
        case .quickEntry: return "plus.circle.fill"
        case .transactions: return "list.bullet"
        case .pending: return "clock.fill"
        case .accounts: return "creditcard.fill"
        case .analytics: return "chart.pie.fill"
        }
    }
    
    var shouldShowBadge: Bool {
        switch self {
        case .pending: return true
        default: return false
        }
    }

}

struct MainTabView: View {
    let container: DependencyContainer

    @State private var selectedTab: AppTab = TestingConfiguration.isRunningTests ? .transactions : .quickEntry
    @State private var showQuickEntrySheet = false
    @EnvironmentObject var pendingViewModel: PendingTransactionsViewModel
    @Environment(\.scenePhase) private var scenePhase

    @ViewBuilder
    private func tabContent<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        if TestingConfiguration.isRunningTests && selectedTab != tab {
            Color.clear.accessibilityHidden(true)
        } else {
            content()
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if !TestingConfiguration.isRunningTests {
                QuickEntryView()
                    .tabItem {
                        Label(AppTab.quickEntry.title, systemImage: AppTab.quickEntry.icon)
                    }
                    .tag(AppTab.quickEntry)
            }

            tabContent(.transactions) {
                TransactionListView()
            }
                .tabItem {
                    Label(AppTab.transactions.title, systemImage: AppTab.transactions.icon)
                }
                .tag(AppTab.transactions)

            tabContent(.pending) {
                PendingTransactionsView()
            }
                .tabItem {
                    Label(AppTab.pending.title, systemImage: AppTab.pending.icon)
                        .accessibilityIdentifier("PendingTab")
                }
                .badge(pendingViewModel.pendingTransactions.count)
                .tag(AppTab.pending)

            tabContent(.accounts) {
                AccountsView()
            }
                .tabItem {
                    Label(AppTab.accounts.title, systemImage: AppTab.accounts.icon)
                        .accessibilityIdentifier("AccountsTab")
                }
                .tag(AppTab.accounts)

            tabContent(.analytics) {
                AnalyticsView(container: container)
            }
                .tabItem {
                    Label(AppTab.analytics.title, systemImage: AppTab.analytics.icon)
                        .accessibilityIdentifier("AnalyticsTab")
                }
                .tag(AppTab.analytics)
        }
        .accessibilityIdentifier("MainView")
        .tint(.blue)
        .onChange(of: scenePhase) { _, scenePhase in
            handleScenePhaseChange(scenePhase)
        }
        .overlay(alignment: .bottomTrailing) {
            if TestingConfiguration.isRunningTests {
                Button {
                    showQuickEntrySheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                        .padding()
                }
                .accessibilityIdentifier("AddTransactionButton")
            }
        }
        .sheet(isPresented: $showQuickEntrySheet) {
            QuickEntryView()
        }

    }

    /// Handles changes in the app's scene phase to manage pending transactions monitoring.
    /// - Parameter phase: The new scene phase of the app.
    @MainActor
    func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            pendingViewModel.resumeMonitoring()
        case .inactive, .background:
            pendingViewModel.pauseMonitoring()
        @unknown default:
            break
        }
    }
}


extension MainTabView {
    func navigateToTab(_ tab: AppTab) {
        selectedTab = tab
    }
    
    func navigateToPendingTransactions() {
        selectedTab = .pending
    }
}

extension AppTab {
    init?(urlPath: String) {
        switch urlPath.lowercased() {
        case "quick-entry": self = .quickEntry
        case "transactions": self = .transactions
        case "pending": self = .pending
        case "accounts": self = .accounts
        case "analytics": self = .analytics
        default: return nil
        }
    }
    
    var urlPath: String {
        switch self {
        case .quickEntry: return "quick-entry"
        case .transactions: return "transactions"
        case .pending: return "pending"
        case .accounts: return "accounts"
        case .analytics: return "analytics"
        }
    }
        
        
}
