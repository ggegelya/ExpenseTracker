//
//  CategoryMigrationService.swift
//  ExpenseTracker
//
//  One-time migration: renames Ukrainian category names to English keys
//  so CategorizationService.merchantPatterns match correctly.
//

import Foundation
import os

private let migrationLogger = Logger(subsystem: "com.expensetracker", category: "CategoryMigration")

@MainActor
final class CategoryMigrationService {

    private let repository: TransactionRepositoryProtocol
    private static let migrationCompleteKey = "CategoryMigrationService.v1Complete"
    private static var learnedCorrectionsKey: String { CategorizationService.learnedCorrectionsKey }

    /// Maps Ukrainian category names (pre-localization overhaul) to English keys.
    static let ukrainianToEnglishMap: [String: String] = [
        "продукти": "groceries",
        "таксі": "taxi",
        "підписки": "subscriptions",
        "комунальні": "utilities",
        "аптека": "pharmacy",
        "кафе": "cafe",
        "одяг": "clothing",
        "розваги": "entertainment",
        "транспорт": "transport",
        "подарунки": "gifts",
        "освіта": "education",
        "спорт": "sports",
        "краса": "beauty",
        "електроніка": "electronics",
        "інше": "other"
    ]

    private let userDefaults: UserDefaults

    init(repository: TransactionRepositoryProtocol, userDefaults: UserDefaults = .standard) {
        self.repository = repository
        self.userDefaults = userDefaults
    }

    /// Runs migration if not already completed. Safe to call on every launch.
    func migrateIfNeeded() async {
        guard !userDefaults.bool(forKey: Self.migrationCompleteKey) else { return }

        migrationLogger.info("Starting category key migration (Ukrainian → English)")

        do {
            let categories = try await repository.getAllCategories()
            var migratedCount = 0

            for category in categories {
                if let englishKey = Self.ukrainianToEnglishMap[category.name.lowercased()], englishKey != category.name {
                    let updated = Category(
                        id: category.id,
                        name: englishKey,
                        icon: category.icon,
                        colorHex: category.colorHex
                    )
                    _ = try await repository.updateCategory(updated)
                    migratedCount += 1
                }
            }

            // Migrate learned corrections in UserDefaults
            migrateLearnedCorrections()

            userDefaults.set(true, forKey: Self.migrationCompleteKey)
            migrationLogger.info("Category migration complete: \(migratedCount) categories renamed")
        } catch {
            // Don't mark complete on failure — retry next launch
            migrationLogger.error("Category migration failed: \(error.localizedDescription)")
        }
    }

    /// Remaps learned correction values from Ukrainian names to English keys.
    private func migrateLearnedCorrections() {
        guard var corrections = userDefaults.dictionary(forKey: Self.learnedCorrectionsKey) as? [String: String] else { return }

        var changed = false
        for (pattern, categoryName) in corrections {
            if let englishKey = Self.ukrainianToEnglishMap[categoryName.lowercased()], englishKey != categoryName {
                corrections[pattern] = englishKey
                changed = true
            }
        }

        if changed {
            userDefaults.set(corrections, forKey: Self.learnedCorrectionsKey)
        }
    }
}
