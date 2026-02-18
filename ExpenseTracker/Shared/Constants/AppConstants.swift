//
//  AppConstants.swift
//  ExpenseTracker
//

import Foundation

// MARK: - UserDefaults Keys

enum UserDefaultsKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let hasShownFirstTransactionCelebration = "hasShownFirstTransactionCelebration"
    static let favoriteCategoryIds = "favoriteCategoryIds"

    /// Returns the UserDefaults key for a given coach mark's shown state.
    static func coachMarkShown(_ id: CoachMarkID) -> String {
        "coachMark.shown.\(id.rawValue)"
    }
}

// MARK: - App Constants

enum AppConstants {
    /// Minimum number of transactions required to show analytics charts
    static let analyticsMinTransactions = 3
}
