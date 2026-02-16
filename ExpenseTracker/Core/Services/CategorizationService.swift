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
    func invalidateCategoryCache()
}

@MainActor
final class CategorizationService: CategorizationServiceProtocol {
    private let repository: TransactionRepositoryProtocol

    /// Shared key for learned corrections in UserDefaults.
    /// Used by both CategorizationService and CategoryMigrationService.
    static let learnedCorrectionsKey = "CategorizationService.learnedCorrections"

    /// Pre-computed reverse map: English key → Ukrainian name.
    /// Safe against duplicate values (keeps first occurrence).
    private static let englishToUkrainianMap: [String: String] = Dictionary(
        CategoryMigrationService.ukrainianToEnglishMap.map { ($1, $0) },
        uniquingKeysWith: { first, _ in first }
    )

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

    private let userDefaults: UserDefaults

    init(repository: TransactionRepositoryProtocol, userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.userDefaults = userDefaults
    }

    func suggestCategory(for description: String, merchantName: String?) async -> (category: Category?, confidence: Float) {
        // Load categories once per suggestion session
        let categories = await loadCategoriesIfNeeded()

        let lowercasedDescription = description.lowercased()
        let lowercasedMerchant = merchantName?.lowercased() ?? ""

        // Check learned corrections first
        let learnedCorrections = userDefaults.dictionary(forKey: Self.learnedCorrectionsKey) as? [String: String] ?? [:]
        for (pattern, categoryName) in learnedCorrections {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                if let category = Self.findCategory(named: categoryName, in: categories) {
                    return (category, 0.95)
                }
            }
        }

        // Try to find category by hardcoded patterns
        for (pattern, categoryName) in merchantPatterns {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                if let category = Self.findCategory(named: categoryName, in: categories) {
                    return (category, 0.85)
                }
            }
        }

        // Default to "other" with low confidence
        if let defaultCategory = Self.findCategory(named: "other", in: categories) {
            return (defaultCategory, 0.3)
        }

        return (nil, 0.0)
    }

    /// Finds a category by name with alias fallback.
    /// Checks: direct match → forward alias (Ukrainian→English) → reverse alias (English→Ukrainian).
    static func findCategory(named name: String, in categories: [Category]) -> Category? {
        // Direct match
        if let match = categories.first(where: { $0.name == name }) {
            return match
        }

        // Forward alias: Ukrainian name → English key
        if let englishKey = CategoryMigrationService.ukrainianToEnglishMap[name.lowercased()] {
            if let match = categories.first(where: { $0.name == englishKey }) {
                return match
            }
        }

        // Reverse alias: English key → Ukrainian name
        if let ukrainianName = englishToUkrainianMap[name.lowercased()] {
            if let match = categories.first(where: { $0.name.lowercased() == ukrainianName }) {
                return match
            }
        }

        return nil
    }

    func learnFromCorrection(description: String, merchantName: String?, correctCategory: Category) async {
        var corrections = userDefaults.dictionary(forKey: Self.learnedCorrectionsKey) as? [String: String] ?? [:]

        // Store the description pattern (lowercased) → category name
        let key = (merchantName ?? description).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        corrections[key] = correctCategory.name
        userDefaults.set(corrections, forKey: Self.learnedCorrectionsKey)
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
