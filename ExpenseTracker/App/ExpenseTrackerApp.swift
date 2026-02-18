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

    @AppStorage(UserDefaultsKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = TestingConfiguration.isRunningTests ? .transactions : .quickEntry

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

        // Reset app state if requested (for UI tests) — must happen before container creation
        // so @AppStorage properties pick up the cleared UserDefaults
        if TestingConfiguration.shouldResetAppState {
            Self.resetAppState()
        }

        // Setup dependency container
        self.container = DependencyContainer(environment: environment)

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
            if hasCompletedOnboarding || (TestingConfiguration.isRunningTests && !TestingConfiguration.shouldShowOnboarding) {
                ZStack {
                    MainTabView(container: container, selectedTab: $selectedTab)

                    if transactionViewModel.showCelebration {
                        CelebrationOverlayView {
                            withAnimation { transactionViewModel.showCelebration = false }
                            // Mark #2: Activate coach mark after celebration is dismissed
                            if transactionViewModel.pendingCoachMark {
                                transactionViewModel.pendingCoachMark = false
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(0.5))
                                    container.coachMarkManager.activate(.firstTransactionSaved)
                                }
                            }
                        }
                    }

                    // Coach mark spotlights — rendered above everything including tab bar
                    CoachMarkSpotlightLayer(coachMarkManager: container.coachMarkManager)
                }
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
                .environmentObject(transactionViewModel)
                .environmentObject(accountsViewModel)
                .environmentObject(pendingViewModel)
                .environmentObject(container.errorHandlingServiceInstance)
                .environmentObject(container.coachMarkManager)
            } else {
                OnboardingView(
                    container: container,
                    onComplete: { hasCompletedOnboarding = true }
                )
                .environmentObject(accountsViewModel)
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
    @Previewable @State var selectedTab: AppTab = .quickEntry
    let previewContainer = DependencyContainer.makeForPreviews()
    return MainTabView(container: previewContainer, selectedTab: $selectedTab)
        .environmentObject(previewContainer.makeTransactionViewModel())
        .environmentObject(previewContainer.makeAccountsViewModel())
        .environmentObject(previewContainer.makePendingTransactionsViewModel())
        .environmentObject(previewContainer.errorHandlingServiceInstance)
        .environmentObject(previewContainer.coachMarkManager)
        .environment(\.managedObjectContext, previewContainer.persistenceController.container.viewContext)
}
