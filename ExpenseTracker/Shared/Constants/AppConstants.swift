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
}

// MARK: - App Constants

enum AppConstants {
    /// Minimum number of transactions required to show analytics charts
    static let analyticsMinTransactions = 3
}
