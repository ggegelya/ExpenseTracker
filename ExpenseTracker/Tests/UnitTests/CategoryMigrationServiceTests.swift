//
//  CategoryMigrationServiceTests.swift
//  ExpenseTracker
//
//  Tests for CategoryMigrationService one-time migration logic.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("Category Migration Service Tests", .serialized)
@MainActor
struct CategoryMigrationServiceTests {

    // MARK: - Migration Map Tests

    @Test("Migration map covers all default categories")
    func migrationMapCoversAllDefaults() {
        let defaultNames = Set(Category.defaults.map { $0.name })
        let englishValues = Set(CategoryMigrationService.ukrainianToEnglishMap.values)

        for name in defaultNames {
            #expect(englishValues.contains(name), "Default category '\(name)' should have a Ukrainian→English mapping")
        }
    }

    @Test("Migration map has no duplicate English values")
    func migrationMapHasNoDuplicateValues() {
        let values = Array(CategoryMigrationService.ukrainianToEnglishMap.values)
        let uniqueValues = Set(values)
        #expect(values.count == uniqueValues.count, "Migration map should not have duplicate English keys")
    }

    // MARK: - Migration Execution Tests

    @Test("migrateIfNeeded renames Ukrainian categories to English keys")
    func migrateRenamesUkrainianToEnglish() async throws {
        let suiteName = "test.migration.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer { testDefaults.removePersistentDomain(forName: suiteName) }

        let mockRepository = MockTransactionRepository()

        // Seed with Ukrainian category names
        let ukrainianCategories = [
            Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50"),
            Category(id: UUID(), name: "таксі", icon: "car.fill", colorHex: "#FFC107"),
            Category(id: UUID(), name: "кафе", icon: "cup.and.saucer.fill", colorHex: "#FF9800")
        ]
        mockRepository.categories = ukrainianCategories

        let sut = CategoryMigrationService(repository: mockRepository, userDefaults: testDefaults)
        await sut.migrateIfNeeded()

        // Verify categories were renamed
        let updatedCategories = mockRepository.categories
        let names = Set(updatedCategories.map { $0.name })
        #expect(names.contains("groceries"))
        #expect(names.contains("taxi"))
        #expect(names.contains("cafe"))
        #expect(!names.contains("продукти"))
        #expect(!names.contains("таксі"))

        // Verify migration flag was set
        #expect(testDefaults.bool(forKey: "CategoryMigrationService.v1Complete"))
    }

    @Test("migrateIfNeeded skips already-English categories")
    func migrateSkipsEnglishCategories() async throws {
        let suiteName = "test.migration.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer { testDefaults.removePersistentDomain(forName: suiteName) }

        let mockRepository = MockTransactionRepository()

        let englishCategories = [
            Category(id: UUID(), name: "groceries", icon: "cart.fill", colorHex: "#4CAF50"),
            Category(id: UUID(), name: "taxi", icon: "car.fill", colorHex: "#FFC107")
        ]
        mockRepository.categories = englishCategories

        let sut = CategoryMigrationService(repository: mockRepository, userDefaults: testDefaults)
        await sut.migrateIfNeeded()

        // No updateCategory calls should have been made
        #expect(mockRepository.callCount(for: "updateCategory(_:)") == 0)
    }

    @Test("migrateIfNeeded does not run twice")
    func migrateDoesNotRunTwice() async throws {
        let suiteName = "test.migration.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer { testDefaults.removePersistentDomain(forName: suiteName) }

        let mockRepository = MockTransactionRepository()

        let ukrainianCategories = [
            Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50")
        ]
        mockRepository.categories = ukrainianCategories

        let sut = CategoryMigrationService(repository: mockRepository, userDefaults: testDefaults)
        await sut.migrateIfNeeded()
        mockRepository.clearCallHistory()

        // Second call should be no-op
        await sut.migrateIfNeeded()
        #expect(mockRepository.callCount(for: "updateCategory(_:)") == 0)
    }

    @Test("migrateIfNeeded migrates learned corrections in UserDefaults")
    func migrateLearnedCorrections() async throws {
        let suiteName = "test.migration.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        defer { testDefaults.removePersistentDomain(forName: suiteName) }

        let mockRepository = MockTransactionRepository()
        mockRepository.categories = []

        // Set up a learned correction with Ukrainian category name
        testDefaults.set(["сільпо": "продукти", "uber": "taxi"], forKey: CategorizationService.learnedCorrectionsKey)

        let sut = CategoryMigrationService(repository: mockRepository, userDefaults: testDefaults)
        await sut.migrateIfNeeded()

        // Check that the Ukrainian value was migrated
        let corrections = testDefaults.dictionary(forKey: CategorizationService.learnedCorrectionsKey) as? [String: String]
        #expect(corrections?["сільпо"] == "groceries")
        #expect(corrections?["uber"] == "taxi") // already English, unchanged
    }
}

// MARK: - CategorizationService Alias Fallback Tests

@Suite("Categorization Service Alias Fallback Tests")
@MainActor
struct CategorizationServiceAliasFallbackTests {

    @Test("suggestCategory works when DB has Ukrainian name but pattern expects English key")
    func suggestCategoryWithUkrainianDbName() async throws {
        let mockRepository = MockTransactionRepository()

        // DB has Ukrainian names (pre-migration state)
        let ukrainianCategory = Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50")
        mockRepository.categories = [ukrainianCategory]

        let sut = CategorizationService(repository: mockRepository)

        // Pattern maps "сільпо" → "groceries" (English key)
        // findCategory should fall back via reverse alias: "groceries" → "продукти"
        let result = await sut.suggestCategory(for: "Сільпо", merchantName: nil)

        #expect(result.category?.id == ukrainianCategory.id)
        #expect(result.confidence == 0.85)
    }

    @Test("findCategory matches directly first")
    func findCategoryMatchesDirectly() {
        let category = Category(id: UUID(), name: "groceries", icon: "cart.fill", colorHex: "#4CAF50")
        let result = CategorizationService.findCategory(named: "groceries", in: [category])
        #expect(result?.id == category.id)
    }

    @Test("findCategory falls back to forward alias (Ukrainian→English)")
    func findCategoryForwardAlias() {
        let category = Category(id: UUID(), name: "groceries", icon: "cart.fill", colorHex: "#4CAF50")
        let result = CategorizationService.findCategory(named: "продукти", in: [category])
        #expect(result?.id == category.id)
    }

    @Test("findCategory falls back to reverse alias (English→Ukrainian)")
    func findCategoryReverseAlias() {
        let category = Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50")
        let result = CategorizationService.findCategory(named: "groceries", in: [category])
        #expect(result?.id == category.id)
    }

    @Test("findCategory returns nil for unknown name")
    func findCategoryReturnsNilForUnknown() {
        let category = Category(id: UUID(), name: "groceries", icon: "cart.fill", colorHex: "#4CAF50")
        let result = CategorizationService.findCategory(named: "nonexistent", in: [category])
        #expect(result == nil)
    }
}
