//
//  MainTabView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 07.09.2025.
//


import SwiftUI

// MARK: - Environment Key for Tab Switching

private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<AppTab> = .constant(.quickEntry)
}

extension EnvironmentValues {
    var selectedTab: Binding<AppTab> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

enum AppTab: Int, CaseIterable, Identifiable {
    case quickEntry = 0
    case transactions
    case pending
    case accounts
    case analytics
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .quickEntry: return String(localized: "tab.add")
        case .transactions: return String(localized: "tab.transactions")
        case .pending: return String(localized: "tab.pending")
        case .accounts: return String(localized: "tab.accounts")
        case .analytics: return String(localized: "tab.analytics")
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
    @Binding var selectedTab: AppTab

    @State private var showQuickEntrySheet = false
    @EnvironmentObject var pendingViewModel: PendingTransactionsViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var errorService: ErrorHandlingService
    @EnvironmentObject var coachMarkManager: CoachMarkManager
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
        .environment(\.selectedTab, $selectedTab)
        .accessibilityIdentifier("MainView")
        .tint(.blue)
        .onChange(of: scenePhase) { _, scenePhase in
            handleScenePhaseChange(scenePhase)
        }
        .overlay(alignment: .top) {
            Group {
                if let toast = errorService.currentToast {
                    ToastView(toast: toast) {
                        errorService.dismissToast()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.easeInOut, value: errorService.currentToast)
        }
        .alert(
            errorService.currentMessage?.title ?? "",
            isPresented: Binding(
                get: { errorService.currentMessage != nil },
                set: { if !$0 { errorService.dismissAlert() } }
            )
        ) {
            if let message = errorService.currentMessage {
                Button(String(localized: "common.close"), role: .cancel) {
                    errorService.dismissAlert()
                }
                if message.isRetryable, let retryAction = message.retryAction {
                    Button(String(localized: "common.retry")) {
                        retryAction()
                    }
                }
            }
        } message: {
            if let message = errorService.currentMessage {
                VStack {
                    Text(message.message)
                    if let suggestion = message.recoverySuggestion {
                        Text(suggestion)
                    }
                }
            }
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
        .onChange(of: selectedTab) { _, newTab in
            // Dismiss mark #2 when navigating to transactions
            if newTab == .transactions && coachMarkManager.shouldShow(.firstTransactionSaved) {
                coachMarkManager.deactivate(.firstTransactionSaved)
            }
            // Dismiss mark #3 when navigating to analytics
            if newTab == .analytics && coachMarkManager.shouldShow(.analyticsReady) {
                coachMarkManager.deactivate(.analyticsReady)
            }
        }
        .onChange(of: transactionViewModel.transactions.count) { _, newCount in
            // Mark #3: Activate analytics tooltip at 3+ transactions
            if newCount >= AppConstants.analyticsMinTransactions {
                coachMarkManager.activate(.analyticsReady)
            }
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
