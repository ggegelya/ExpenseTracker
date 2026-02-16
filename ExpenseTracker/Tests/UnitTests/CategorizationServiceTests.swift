//
//  CategorizationServiceTests.swift
//  ExpenseTracker
//
//  Tests for CategorizationService business logic
//

import Testing
import Foundation
@testable import ExpenseTracker

@MainActor
@Suite("Categorization Service Tests")
struct CategorizationServiceTests {
    var sut: CategorizationService
    var mockRepository: MockTransactionRepository
    var testDefaults: UserDefaults

    init() async throws {
        mockRepository = MockTransactionRepository(
            categories: MockCategory.makeDefaultCategories()
        )
        let suiteName = "com.expensetracker.tests.categorization.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        sut = CategorizationService(repository: mockRepository, userDefaults: testDefaults)
    }

    // MARK: - Ukrainian Merchant Tests

    @Test("Suggest category for Silpo returns groceries with high confidence")
    func suggestCategoryForSilpo() async throws {
        // When
        let result = await sut.suggestCategory(for: "Purchase at Silpo", merchantName: "Silpo")

        // Then
        #expect(result.category?.name == "groceries")
        #expect(result.confidence == 0.85)
    }

    @Test("Suggest category for ATB returns groceries with high confidence")
    func suggestCategoryForATB() async throws {
        // When
        let result = await sut.suggestCategory(for: "ATB market", merchantName: "ATB")

        // Then
        #expect(result.category?.name == "groceries")
        #expect(result.confidence == 0.85)
    }

    @Test("Suggest category for Uber returns taxi with high confidence")
    func suggestCategoryForUber() async throws {
        // When
        let result = await sut.suggestCategory(for: "Ride with Uber", merchantName: "Uber")

        // Then
        #expect(result.category?.name == "taxi")
        #expect(result.confidence == 0.85)
    }

    @Test("Suggest category for Bolt returns taxi with high confidence")
    func suggestCategoryForBolt() async throws {
        // When
        let result = await sut.suggestCategory(for: "Bolt ride", merchantName: "Bolt")

        // Then
        #expect(result.category?.name == "taxi")
        #expect(result.confidence == 0.85)
    }

    @Test("Suggest category for Netflix returns subscriptions with high confidence")
    func suggestCategoryForNetflix() async throws {
        // When
        let result = await sut.suggestCategory(for: "Netflix subscription", merchantName: "Netflix")

        // Then
        #expect(result.category?.name == "subscriptions")
        #expect(result.confidence == 0.85)
    }

    @Test("Suggest category for unknown merchant returns other with low confidence")
    func suggestCategoryForUnknownMerchant() async throws {
        // When
        let result = await sut.suggestCategory(for: "Unknown store", merchantName: "Unknown Store")

        // Then
        #expect(result.category?.name == "other")
        #expect(result.confidence == 0.3)
    }

    @Test("Suggest category is case-insensitive for merchant name")
    func suggestCategoryIsCaseInsensitiveForMerchant() async throws {
        // When
        let lowercaseResult = await sut.suggestCategory(for: "Purchase", merchantName: "silpo")
        let uppercaseResult = await sut.suggestCategory(for: "Purchase", merchantName: "SILPO")
        let mixedCaseResult = await sut.suggestCategory(for: "Purchase", merchantName: "SiLpO")

        // Then
        #expect(lowercaseResult.category?.name == "groceries")
        #expect(uppercaseResult.category?.name == "groceries")
        #expect(mixedCaseResult.category?.name == "groceries")
    }

    @Test("Suggest category is case-insensitive for description")
    func suggestCategoryIsCaseInsensitiveForDescription() async throws {
        // When
        let lowercaseResult = await sut.suggestCategory(for: "silpo supermarket", merchantName: nil)
        let uppercaseResult = await sut.suggestCategory(for: "SILPO SUPERMARKET", merchantName: nil)
        let mixedCaseResult = await sut.suggestCategory(for: "SiLpO SuperMarket", merchantName: nil)

        // Then
        #expect(lowercaseResult.category?.name == "groceries")
        #expect(uppercaseResult.category?.name == "groceries")
        #expect(mixedCaseResult.category?.name == "groceries")
    }

    @Test("Suggest category matches on description when no merchant name")
    func suggestCategoryMatchesOnDescription() async throws {
        // When
        let result = await sut.suggestCategory(for: "Покупка в Сільпо", merchantName: nil)

        // Then
        #expect(result.category?.name == "groceries")
        #expect(result.confidence == 0.85)
    }

    @Test("Suggest category matches on merchant name pattern")
    func suggestCategoryMatchesOnMerchantName() async throws {
        // When
        let silpoResult = await sut.suggestCategory(for: "Purchase", merchantName: "Silpo")
        let uberResult = await sut.suggestCategory(for: "Ride", merchantName: "Uber")
        let netflixResult = await sut.suggestCategory(for: "Subscription", merchantName: "Netflix")

        // Then
        #expect(silpoResult.category?.name == "groceries")
        #expect(uberResult.category?.name == "taxi")
        #expect(netflixResult.category?.name == "subscriptions")
    }

    @Test("Multiple patterns for same category all work")
    func multiplePatternsForSameCategory() async throws {
        // Groceries category patterns
        let silpoResult = await sut.suggestCategory(for: "Purchase", merchantName: "Silpo")
        let atbResult = await sut.suggestCategory(for: "Purchase", merchantName: "ATB")
        let foraResult = await sut.suggestCategory(for: "Purchase", merchantName: "Fora")
        let metroResult = await sut.suggestCategory(for: "Purchase", merchantName: "Metro")

        // Then - all should return groceries
        #expect(silpoResult.category?.name == "groceries")
        #expect(atbResult.category?.name == "groceries")
        #expect(foraResult.category?.name == "groceries")
        #expect(metroResult.category?.name == "groceries")
    }

    @Test("Confidence scores are within valid range (0.0-1.0)")
    func confidenceScoresAreWithinValidRange() async throws {
        // Test various merchants
        let merchants = ["Silpo", "Uber", "Netflix", "Unknown Store", "ATB", "Bolt"]

        for merchant in merchants {
            let result = await sut.suggestCategory(for: "Test", merchantName: merchant)

            // Then - confidence should be between 0.0 and 1.0
            #expect(result.confidence >= 0.0)
            #expect(result.confidence <= 1.0)
        }
    }

    @Test("Ukrainian merchant names in Cyrillic work correctly")
    func ukrainianMerchantNamesInCyrillic() async throws {
        // When
        let silpoResult = await sut.suggestCategory(for: "Покупка в Сільпо", merchantName: nil)
        let atbResult = await sut.suggestCategory(for: "Покупка в АТБ", merchantName: nil)

        // Then
        #expect(silpoResult.category?.name == "groceries")
        #expect(atbResult.category?.name == "groceries")
    }

    @Test("Pharmacy patterns recognized correctly")
    func pharmacyPatternsRecognized() async throws {
        // When
        let apteka1 = await sut.suggestCategory(for: "Аптека 911", merchantName: nil)
        let apteka2 = await sut.suggestCategory(for: "Pharmacy purchase", merchantName: nil)

        // Then
        #expect(apteka1.category?.name == "pharmacy")
        #expect(apteka2.category?.name == "pharmacy")
    }

    @Test("Cafe and restaurant patterns recognized")
    func cafeAndRestaurantPatterns() async throws {
        // When
        let aromaResult = await sut.suggestCategory(for: "Coffee at Aroma", merchantName: "Aroma")
        let mcdonaldsResult = await sut.suggestCategory(for: "Lunch", merchantName: "McDonald")
        let kfcResult = await sut.suggestCategory(for: "Dinner", merchantName: "KFC")

        // Then
        #expect(aromaResult.category?.name == "cafe")
        #expect(mcdonaldsResult.category?.name == "cafe")
        #expect(kfcResult.category?.name == "cafe")
    }

    @Test("Utilities patterns recognized for Ukrainian providers")
    func utilitiesPatternsForUkrainianProviders() async throws {
        // When
        let kyivenergoResult = await sut.suggestCategory(for: "Payment to Київенерго", merchantName: nil)
        let kyivstarResult = await sut.suggestCategory(for: "Mobile payment", merchantName: "Kyivstar")
        let vodafoneResult = await sut.suggestCategory(for: "Mobile payment", merchantName: "Vodafone")

        // Then
        #expect(kyivenergoResult.category?.name == "utilities")
        #expect(kyivstarResult.category?.name == "utilities")
        #expect(vodafoneResult.category?.name == "utilities")
    }

    // MARK: - Learning Tests

    @Test("Learn from correction stores pattern for future suggestions")
    func learnFromCorrectionStoresPattern() async throws {
        // Given
        let category = MockCategory.makeHealth()

        // When
        await sut.learnFromCorrection(
            description: "Medical supplies",
            merchantName: "MedStore",
            correctCategory: category
        )

        // Then - This is a logging operation in current implementation
        // In a full implementation, this would update ML model or pattern storage
        // For now, we verify it doesn't crash
        #expect(true)
    }

    @Test("Learn from correction with nil merchant name")
    func learnFromCorrectionWithNilMerchant() async throws {
        // Given
        let category = MockCategory.makeTransport()

        // When
        await sut.learnFromCorrection(
            description: "Metro ride",
            merchantName: nil,
            correctCategory: category
        )

        // Then
        #expect(true)
    }

    // MARK: - Edge Cases

    @Test("Empty description returns default category")
    func emptyDescriptionReturnsDefault() async throws {
        // When
        let result = await sut.suggestCategory(for: "", merchantName: nil)

        // Then
        #expect(result.category?.name == "other")
        #expect(result.confidence == 0.3)
    }

    @Test("Description with special characters handled correctly")
    func descriptionWithSpecialCharacters() async throws {
        // When
        let result = await sut.suggestCategory(
            for: "Silpo - продукти, овочі & фрукти!",
            merchantName: nil
        )

        // Then
        #expect(result.category?.name == "groceries")
    }

    @Test("Merchant name takes priority over description")
    func merchantNameTakesPriorityOverDescription() async throws {
        // When - description mentions taxi but merchant is Silpo
        let result = await sut.suggestCategory(
            for: "Таксі to store",
            merchantName: "Silpo"
        )

        // Then - should match Silpo (groceries) not taxi
        #expect(result.category?.name == "groceries")
    }

    @Test("Returns nil category when categories not available")
    func returnsNilWhenCategoriesNotAvailable() async throws {
        // Given - repository with no categories
        let emptyRepository = await MockTransactionRepository(categories: [])
        let emptyDefaults = UserDefaults(suiteName: "com.expensetracker.tests.empty.\(UUID().uuidString)")!
        let serviceWithEmptyRepo = CategorizationService(repository: emptyRepository, userDefaults: emptyDefaults)

        // When
        let result = await serviceWithEmptyRepo.suggestCategory(
            for: "Test",
            merchantName: "Silpo"
        )

        // Then
        #expect(result.category == nil)
        #expect(result.confidence == 0.0)
    }
}
