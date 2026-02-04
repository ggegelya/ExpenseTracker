//
//  CategorizationService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation

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
        // Продукти
        "сільпо": "продукти", "silpo": "продукти",
        "атб": "продукти", "atb": "продукти",
        "фора": "продукти", "fora": "продукти",
        "метро": "продукти", "metro": "продукти",
        "novus": "продукти", "новус": "продукти",
        "ашан": "продукти", "auchan": "продукти",
        "варус": "продукти", "varus": "продукти",

        // Таксі
        "uber": "таксі", "убер": "таксі",
        "bolt": "таксі", "болт": "таксі",
        "uklon": "таксі", "уклон": "таксі",

        // Підписки
        "netflix": "підписки", "spotify": "підписки",
        "youtube": "підписки", "apple": "підписки",
        "google": "підписки", "adobe": "підписки",

        // Аптеки
        "аптека": "аптека", "pharmacy": "аптека",
        "911": "аптека", "д.с.": "аптека",
        "подорожник": "аптека",

        // Кафе і ресторани
        "aroma": "кафе", "starbucks": "кафе",
        "mcdonald": "кафе", "kfc": "кафе",
        "pizza": "кафе", "sushi": "кафе",

        // Комуналка
        "київенерго": "комуналка", "водоканал": "комуналка",
        "київгаз": "комуналка", "kyivstar": "комуналка",
        "vodafone": "комуналка", "lifecell": "комуналка"
    ]

    init(repository: TransactionRepositoryProtocol) {
        self.repository = repository
    }

    func suggestCategory(for description: String, merchantName: String?) async -> (category: Category?, confidence: Float) {
        let lowercasedDescription = description.lowercased()
        let lowercasedMerchant = merchantName?.lowercased() ?? ""

        // Check learned corrections first
        let learnedCorrections = UserDefaults.standard.dictionary(forKey: Self.learnedCorrectionsKey) as? [String: String] ?? [:]
        for (pattern, categoryName) in learnedCorrections {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                if let category = await categoryNamed(categoryName) {
                    return (category, 0.95)
                }
            }
        }

        // Try to find category by hardcoded patterns
        for (pattern, categoryName) in merchantPatterns {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                if let category = await categoryNamed(categoryName) {
                    return (category, 0.85)
                }
            }
        }

        // Default to "інше" with low confidence
        if let defaultCategory = await categoryNamed("інше") {
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

    private func categoryNamed(_ name: String) async -> Category? {
        do {
            let categories = try await repository.getAllCategories()
            return categories.first(where: { $0.name == name })
        } catch {
            print("Failed to get categories: \(error)")
            return nil
        }
    }
}
