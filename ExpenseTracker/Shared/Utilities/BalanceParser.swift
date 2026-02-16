//
//  BalanceParser.swift
//  ExpenseTracker
//
//  Parses user-entered balance strings (supports comma and dot separators).
//

import Foundation

enum BalanceParser {
    /// Parses a balance string into a Decimal value.
    /// Supports both comma and dot as decimal separators.
    /// Returns 0 for empty, whitespace-only, or invalid input.
    static func parse(_ input: String) -> Decimal {
        let cleaned = input
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: cleaned) ?? 0
    }
}
