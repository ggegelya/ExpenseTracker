//
//  CategorizationService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import os

private let categorizationLogger = Logger(subsystem: "com.expensetracker", category: "Categorization")

@MainActor
protocol CategorizationServiceProtocol {
    func suggestCategory(for description: String, merchantName: String?) async -> (category: Category?, confidence: Float)
    func learnFromCorrection(description: String, merchantName: String?, correctCategory: Category) async
}

@MainActor
final class CategorizationService: CategorizationServiceProtocol {
    private let repository: TransactionRepositoryProtocol
    private static let learnedCorrectionsKey = "CategorizationService.learnedCorrections"

    // Merchant patterns for Ukrainian market
    private let merchantPatterns: [String: String] = [
        // Groceries
        "сільпо": "groceries", "silpo": "groceries",
        "атб": "groceries", "atb": "groceries",
        "фора": "groceries", "fora": "groceries",
        "метро": "groceries", "metro": "groceries",
        "novus": "groceries", "новус": "groceries",
        "ашан": "groceries", "auchan": "groceries",
        "варус": "groceries", "varus": "groceries",

        // Taxi
        "uber": "taxi", "убер": "taxi",
        "bolt": "taxi", "болт": "taxi",
        "uklon": "taxi", "уклон": "taxi",

        // Subscriptions
        "netflix": "subscriptions", "spotify": "subscriptions",
        "youtube": "subscriptions", "apple": "subscriptions",
        "google": "subscriptions", "adobe": "subscriptions",

        // Pharmacy
        "аптека": "pharmacy", "pharmacy": "pharmacy",
        "911": "pharmacy", "д.с.": "pharmacy",
        "подорожник": "pharmacy",

        // Cafe
        "aroma": "cafe", "starbucks": "cafe",
        "mcdonald": "cafe", "kfc": "cafe",
        "pizza": "cafe", "sushi": "cafe",

        // Utilities
        "київенерго": "utilities", "водоканал": "utilities",
        "київгаз": "utilities", "kyivstar": "utilities",
        "vodafone": "utilities", "lifecell": "utilities"
    ]

    /// Cached categories to avoid N+1 queries on every suggestCategory call.
    private var cachedCategories: [Category]?

    init(repository: TransactionRepositoryProtocol) {
        self.repository = repository
    }

    func suggestCategory(for description: String, merchantName: String?) async -> (category: Category?, confidence: Float) {
        // Load categories once per suggestion session
        let categories = await loadCategoriesIfNeeded()

        let lowercasedDescription = description.lowercased()
        let lowercasedMerchant = merchantName?.lowercased() ?? ""

        // Check learned corrections first
        let learnedCorrections = UserDefaults.standard.dictionary(forKey: Self.learnedCorrectionsKey) as? [String: String] ?? [:]
        for (pattern, categoryName) in learnedCorrections {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                if let category = categories.first(where: { $0.name == categoryName }) {
                    return (category, 0.95)
                }
            }
        }

        // Try to find category by hardcoded patterns
        for (pattern, categoryName) in merchantPatterns {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                if let category = categories.first(where: { $0.name == categoryName }) {
                    return (category, 0.85)
                }
            }
        }

        // Default to "other" with low confidence
        if let defaultCategory = categories.first(where: { $0.name == "other" }) {
            return (defaultCategory, 0.3)
        }

        return (nil, 0.0)
    }

    func learnFromCorrection(description: String, merchantName: String?, correctCategory: Category) async {
        var corrections = UserDefaults.standard.dictionary(forKey: Self.learnedCorrectionsKey) as? [String: String] ?? [:]

        // Store the description pattern (lowercased) → category name
        let key = (merchantName ?? description).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        corrections[key] = correctCategory.name
        UserDefaults.standard.set(corrections, forKey: Self.learnedCorrectionsKey)
    }

    private func loadCategoriesIfNeeded() async -> [Category] {
        if let cached = cachedCategories { return cached }
        do {
            let categories = try await repository.getAllCategories()
            cachedCategories = categories
            return categories
        } catch {
            categorizationLogger.error("Failed to get categories: \(error.localizedDescription)")
            return []
        }
    }

    /// Invalidates the category cache (call when categories change).
    func invalidateCategoryCache() {
        cachedCategories = nil
    }
}
