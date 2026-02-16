//
//  Account.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import Foundation
import SwiftUI

// MARK: - Account Type

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case card = "Card"
    case savings = "Savings"
    case investment = "Investment"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .cash: return String(localized: "accountType.cash")
        case .card: return String(localized: "accountType.card")
        case .savings: return String(localized: "accountType.savings")
        case .investment: return String(localized: "accountType.investment")
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .savings: return "doc.text.image"
        case .investment: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: String {
        switch self {
        case .cash: return "green"
        case .card: return "blue"
        case .savings: return "orange"
        case .investment: return "purple"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .cash: return .green
        case .card: return .blue
        case .savings: return .orange
        case .investment: return .purple
        }
    }
}

// MARK: - Currency

enum Currency: String, Codable, CaseIterable, Identifiable {
    case uah = "UAH"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .uah: return "₴"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var localizedName: String {
        switch self {
        case .uah: return String(localized: "currency.uah")
        case .usd: return String(localized: "currency.usd")
        case .eur: return String(localized: "currency.eur")
        }
    }
}

// MARK: - Account

struct Account: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let tag: String
    var balance: Decimal
    var isDefault: Bool
    var accountType: AccountType
    var currency: Currency
    var lastTransactionDate: Date?

    /// Localized display name. Resolves "account.\(name)" via localization,
    /// falls back to raw name for user-created accounts.
    var displayName: String {
        let key = "account.\(name)"
        let localized = String(localized: String.LocalizationValue(key))
        return localized == key ? name : localized
    }

    init(id: UUID = UUID(), name: String, tag: String, balance: Decimal = 0, isDefault: Bool = false, accountType: AccountType = .card, currency: Currency = .uah, lastTransactionDate: Date? = nil) {
        self.id = id
        self.name = name
        self.tag = tag
        self.balance = balance
        self.isDefault = isDefault
        self.accountType = accountType
        self.currency = currency
        self.lastTransactionDate = lastTransactionDate
    }

    static let defaultAccount = Account(id: UUID(), name: "default_card", tag: "#main", balance: 0, isDefault: true, accountType: .card, currency: .uah)
}

// MARK: - Account Validation

extension Account {
    enum ValidationError: LocalizedError {
        case emptyName
        case nameTooLong
        case emptyTag
        case invalidTagFormat
        case duplicateTag

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return String(localized: "validation.account.emptyName")
            case .nameTooLong:
                return String(localized: "validation.account.nameTooLong")
            case .emptyTag:
                return String(localized: "validation.account.emptyTag")
            case .invalidTagFormat:
                return String(localized: "validation.account.invalidTagFormat")
            case .duplicateTag:
                return String(localized: "validation.account.duplicateTag")
            }
        }
    }

    static func validate(name: String, tag: String, existingTags: [String] = []) throws {
        // Name validation
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName
        }

        guard name.count <= 50 else {
            throw ValidationError.nameTooLong
        }

        // Tag validation
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else {
            throw ValidationError.emptyTag
        }

        guard trimmedTag.hasPrefix("#") else {
            throw ValidationError.invalidTagFormat
        }

        // Check for duplicate tags
        if existingTags.contains(trimmedTag) {
            throw ValidationError.duplicateTag
        }
    }

    var balanceColor: Color {
        if balance > 0 {
            return .green
        } else if balance < 0 {
            return .red
        } else {
            return .primary
        }
    }

    func formattedBalance() -> String {
        Formatters.currencyString(amount: balance,
                                  currency: currency,
                                  minFractionDigits: 0,
                                  maxFractionDigits: 2)
    }
}

