//
//  CoachMarkID.swift
//  ExpenseTracker
//

import Foundation

/// Identifiers for all contextual coach marks in the app.
/// Each mark fires once and is persisted via UserDefaults.
enum CoachMarkID: String, CaseIterable, Sendable {
    /// Pulsing ring on amount field for fresh users
    case quickEntryAmountField
    /// Tooltip pointing to transactions tab after first save
    case firstTransactionSaved
    /// Tooltip pointing to analytics tab when 3+ transactions
    case analyticsReady
    /// Tooltip on category chip when auto-detection fires
    case autoCategoryDetected
    /// Swipe hint on first transaction row
    case swipeActionsHint
}
