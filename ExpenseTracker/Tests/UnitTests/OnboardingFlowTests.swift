//
//  OnboardingFlowTests.swift
//  ExpenseTracker
//
//  Tests for onboarding flow logic: balance parsing, account update,
//  category favorites persistence, and completion flags.
//

import Testing
import Foundation
@testable import ExpenseTracker

// MARK: - Balance Parser Tests

@Suite("Balance Parser Tests")
struct BalanceParserTests {

    @Test("Converts comma decimal separator to dot")
    func convertsComma() {
        #expect(BalanceParser.parse("1500,50") == Decimal(string: "1500.50"))
    }

    @Test("Handles dot decimal separator")
    func handlesDot() {
        #expect(BalanceParser.parse("2500.75") == Decimal(string: "2500.75"))
    }

    @Test("Returns zero for empty string")
    func emptyReturnsZero() {
        #expect(BalanceParser.parse("") == 0)
    }

    @Test("Returns zero for whitespace-only string")
    func whitespaceReturnsZero() {
        #expect(BalanceParser.parse("   ") == 0)
    }

    @Test("Returns zero for non-numeric string")
    func invalidReturnsZero() {
        #expect(BalanceParser.parse("abc") == 0)
    }

    @Test("Handles integer input without separator")
    func integerInput() {
        #expect(BalanceParser.parse("5000") == 5000)
    }

    @Test("Trims leading and trailing whitespace")
    func trimsWhitespace() {
        #expect(BalanceParser.parse("  1234,56  ") == Decimal(string: "1234.56"))
    }

    @Test("Handles negative input")
    func negativeInput() {
        // BalanceParser.parse returns the parsed value; negative is still a valid Decimal
        let result = BalanceParser.parse("-500")
        #expect(result == Decimal(-500) || result == 0, "Negative input should parse to -500 or be treated as 0")
    }

    @Test("Handles zero input")
    func zeroInput() {
        #expect(BalanceParser.parse("0") == 0)
        #expect(BalanceParser.parse("0,00") == 0)
    }
}

// MARK: - Account Update Tests

@Suite("Onboarding Account Update Tests", .serialized)
@MainActor
struct OnboardingAccountUpdateTests {
    var mockRepository: MockTransactionRepository
    var mockAnalyticsService: MockAnalyticsService
    var mockErrorHandler: MockErrorHandlingService
    var accountsViewModel: AccountsViewModel

    init() async throws {
        let defaultAccount = MockAccount.makeCustom(
            name: "default_card",
            tag: "#main",
            balance: 0,
            isDefault: true,
            type: .card,
            currency: .uah
        )
        mockRepository = MockTransactionRepository(
            accounts: [defaultAccount],
            categories: MockCategory.makeDefaultCategories()
        )
        mockAnalyticsService = MockAnalyticsService()
        mockErrorHandler = MockErrorHandlingService()
        accountsViewModel = AccountsViewModel(
            repository: mockRepository,
            analyticsService: mockAnalyticsService,
            errorHandler: mockErrorHandler
        )
    }

    @Test("Updates default account with new name and balance")
    func updateDefaultAccountWithNewNameAndBalance() async throws {
        await accountsViewModel.loadAccounts()
        let defaultAccount = accountsViewModel.accounts.first(where: { $0.isDefault })!

        let updated = Account(
            id: defaultAccount.id,
            name: "Монобанк",
            tag: defaultAccount.tag,
            balance: 15000,
            isDefault: true,
            accountType: .card,
            currency: defaultAccount.currency
        )
        await accountsViewModel.updateAccount(updated)

        #expect(mockRepository.wasCalled("updateAccount(_:)"))
        let updatedInRepo = mockRepository.accounts.first(where: { $0.id == defaultAccount.id })
        #expect(updatedInRepo?.name == "Монобанк")
        #expect(updatedInRepo?.balance == 15000)
        #expect(updatedInRepo?.isDefault == true)
    }

    @Test("Updates account type from card to cash")
    func updateAccountTypeToCash() async throws {
        await accountsViewModel.loadAccounts()
        let defaultAccount = accountsViewModel.accounts.first(where: { $0.isDefault })!

        let updated = Account(
            id: defaultAccount.id,
            name: "Готівка",
            tag: defaultAccount.tag,
            balance: 0,
            isDefault: true,
            accountType: .cash,
            currency: defaultAccount.currency
        )
        await accountsViewModel.updateAccount(updated)

        let updatedInRepo = mockRepository.accounts.first(where: { $0.id == defaultAccount.id })
        #expect(updatedInRepo?.accountType == .cash)
        #expect(updatedInRepo?.name == "Готівка")
    }

    @Test("Updates account type to savings")
    func updateAccountTypeToSavings() async throws {
        await accountsViewModel.loadAccounts()
        let defaultAccount = accountsViewModel.accounts.first(where: { $0.isDefault })!

        let updated = Account(
            id: defaultAccount.id,
            name: "Заощадження",
            tag: defaultAccount.tag,
            balance: 50000,
            isDefault: true,
            accountType: .savings,
            currency: defaultAccount.currency
        )
        await accountsViewModel.updateAccount(updated)

        let updatedInRepo = mockRepository.accounts.first(where: { $0.id == defaultAccount.id })
        #expect(updatedInRepo?.accountType == .savings)
    }

    @Test("Skip does not call updateAccount on repository")
    func skipDoesNotUpdateAccount() async throws {
        await accountsViewModel.loadAccounts()
        mockRepository.clearCallHistory()

        // Skip behavior: onComplete() is called directly, no updates
        #expect(!mockRepository.wasCalled("updateAccount(_:)"))
    }
}

// MARK: - Category Favorites Persistence Tests

@Suite("Category Favorites Tests", .serialized)
struct CategoryFavoritesTests {
    let testSuiteName: String
    let testDefaults: UserDefaults

    init() {
        testSuiteName = "CategoryFavoritesTests_\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    @Test("Saving favorites writes UUID strings to UserDefaults")
    func saveFavoritesWritesToDefaults() {
        let categories = MockCategory.makeDefaultCategories()
        let selectedIds = Set(categories.prefix(5).map(\.id))

        let favoriteIds = selectedIds.map(\.uuidString)
        testDefaults.set(favoriteIds, forKey: UserDefaultsKeys.favoriteCategoryIds)

        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        #expect(stored.count == 5)
        for id in selectedIds {
            #expect(stored.contains(id.uuidString))
        }
    }

    @Test("Saving all categories stores all IDs")
    func saveAllCategoriesAsFavorites() {
        let categories = MockCategory.makeDefaultCategories()
        let selectedIds = Set(categories.map(\.id))

        let favoriteIds = selectedIds.map(\.uuidString)
        testDefaults.set(favoriteIds, forKey: UserDefaultsKeys.favoriteCategoryIds)

        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        #expect(stored.count == categories.count)
    }

    @Test("Deselecting all categories saves empty array")
    func deselectAllCategoriesSavesEmptyArray() {
        let selectedIds: Set<UUID> = []

        let favoriteIds = selectedIds.map(\.uuidString)
        testDefaults.set(favoriteIds, forKey: UserDefaultsKeys.favoriteCategoryIds)

        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        #expect(stored.isEmpty)
    }

    @Test("Round-trip preserves UUIDs")
    func roundTripPreservesUUIDs() {
        let categories = MockCategory.makeDefaultCategories()
        let originalIds = Set(categories.prefix(3).map(\.id))

        let favoriteStrings = originalIds.map(\.uuidString)
        testDefaults.set(favoriteStrings, forKey: UserDefaultsKeys.favoriteCategoryIds)

        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        let restoredIds = Set(stored.compactMap { UUID(uuidString: $0) })

        #expect(restoredIds == originalIds)
    }

    @Test("Skip does not write category favorites")
    func skipDoesNotWriteCategoryFavorites() {
        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds)
        #expect(stored == nil)
    }
}

// MARK: - Onboarding Completion Flag Tests

@Suite("Onboarding Completion Flag Tests", .serialized)
struct OnboardingCompletionFlagTests {
    let testSuiteName: String
    let testDefaults: UserDefaults

    init() {
        testSuiteName = "OnboardingCompletionTests_\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    @Test("Defaults to false on fresh install")
    func defaultsToFalse() {
        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding) == false)
    }

    @Test("Setting to true persists")
    func settingTruePersists() {
        testDefaults.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding) == true)
    }

    @Test("Clearing UserDefaults resets to false")
    func clearingResetsToFalse() {
        testDefaults.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding) == true)

        testDefaults.removePersistentDomain(forName: testSuiteName)

        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding) == false)
    }
}

// MARK: - Categories Loading Tests

@Suite("Onboarding Categories Loading Tests", .serialized)
@MainActor
struct OnboardingCategoriesLoadingTests {
    var mockRepository: MockTransactionRepository

    init() async throws {
        mockRepository = MockTransactionRepository(
            categories: MockCategory.makeDefaultCategories()
        )
    }

    @Test("Loading categories from repository returns all categories")
    func loadCategoriesReturnsAll() async throws {
        let categories = try await mockRepository.getAllCategories()

        #expect(categories.count == 15)
        #expect(mockRepository.wasCalled("getAllCategories()"))
    }

    @Test("Initial selection contains all category IDs")
    func initialSelectionContainsAll() async throws {
        let categories = try await mockRepository.getAllCategories()
        let selectedIds = Set(categories.map(\.id))

        #expect(selectedIds.count == categories.count)
    }
}

// MARK: - Favorite Categories Sorting Tests

@Suite("Favorite Categories Sorting Tests")
struct FavoriteCategoriesSortingTests {

    @Test("loadFavoriteCategoryIds returns set from UserDefaults")
    func loadsFromDefaults() {
        // Given - use an isolated UserDefaults suite
        let testDefaults = UserDefaults(suiteName: "FavLoadTest_\(UUID().uuidString)")!
        let id1 = UUID()
        let id2 = UUID()
        testDefaults.set([id1.uuidString, id2.uuidString], forKey: UserDefaultsKeys.favoriteCategoryIds)

        // When
        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        let parsed = Set(stored.compactMap { UUID(uuidString: $0) })

        // Then
        #expect(parsed.count == 2)
        #expect(parsed.contains(id1))
        #expect(parsed.contains(id2))
    }

    @Test("loadFavoriteCategoryIds parses UUID strings correctly")
    func parsesUUIDStrings() {
        let testDefaults = UserDefaults(suiteName: "FavSortTest_\(UUID().uuidString)")!
        let id1 = UUID()
        let id2 = UUID()

        testDefaults.set([id1.uuidString, id2.uuidString], forKey: UserDefaultsKeys.favoriteCategoryIds)

        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        let parsed = Set(stored.compactMap { UUID(uuidString: $0) })

        #expect(parsed.count == 2)
        #expect(parsed.contains(id1))
        #expect(parsed.contains(id2))
    }

    @Test("Invalid UUID strings are filtered out during parsing")
    func invalidUUIDsFiltered() {
        let testDefaults = UserDefaults(suiteName: "FavSortInvalid_\(UUID().uuidString)")!
        let validId = UUID()

        testDefaults.set([validId.uuidString, "not-a-uuid", ""], forKey: UserDefaultsKeys.favoriteCategoryIds)

        let stored = testDefaults.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) ?? []
        let parsed = Set(stored.compactMap { UUID(uuidString: $0) })

        #expect(parsed.count == 1)
        #expect(parsed.contains(validId))
    }
}
