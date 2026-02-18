//
//  DataSeederTests.swift
//  ExpenseTracker
//
//  Tests for DataSeeder initial data setup
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("DataSeeder Tests", .serialized)
@MainActor
struct DataSeederTests {
    var sut: DataSeeder
    var mockRepository: MockTransactionRepository

    init() async throws {
        mockRepository = MockTransactionRepository()
        sut = DataSeeder(repository: mockRepository)
    }

    @Test("setupInitialDataIfNeeded creates default account when accounts empty")
    func createsDefaultAccountWhenEmpty() async throws {
        // Given - repository has no accounts
        #expect(mockRepository.accounts.isEmpty)

        // When
        await sut.setupInitialDataIfNeeded()

        // Then
        #expect(mockRepository.accounts.count == 1)
        #expect(mockRepository.accounts.first?.name == "default_card")
        #expect(mockRepository.accounts.first?.isDefault == true)
        #expect(mockRepository.accounts.first?.tag == "#main")
    }

    @Test("setupInitialDataIfNeeded creates 15 default categories when categories empty")
    func createsDefaultCategoriesWhenEmpty() async throws {
        // Given - repository has no categories
        #expect(mockRepository.categories.isEmpty)

        // When
        await sut.setupInitialDataIfNeeded()

        // Then
        #expect(mockRepository.categories.count == 15)
        let categoryNames = Set(mockRepository.categories.map(\.name))
        #expect(categoryNames.contains("groceries"))
        #expect(categoryNames.contains("taxi"))
        #expect(categoryNames.contains("other"))
    }

    @Test("setupInitialDataIfNeeded skips creation when accounts already exist")
    func skipsAccountCreationWhenAccountsExist() async throws {
        // Given - repository already has an account
        let existingAccount = Account(id: UUID(), name: "existing", tag: "#existing", balance: 1000, isDefault: true)
        mockRepository.accounts = [existingAccount]

        // When
        await sut.setupInitialDataIfNeeded()

        // Then - should not create another account
        #expect(mockRepository.accounts.count == 1)
        #expect(mockRepository.accounts.first?.name == "existing")
    }

    @Test("setupInitialDataIfNeeded skips creation when categories already exist")
    func skipsCategoryCreationWhenCategoriesExist() async throws {
        // Given - repository already has categories
        let existingCategory = Category(id: UUID(), name: "custom", icon: "star", colorHex: "#FF0000")
        mockRepository.categories = [existingCategory]

        // When
        await sut.setupInitialDataIfNeeded()

        // Then - should not create default categories
        #expect(mockRepository.categories.count == 1)
        #expect(mockRepository.categories.first?.name == "custom")
    }

    @Test("setupInitialDataIfNeeded is idempotent")
    func isIdempotent() async throws {
        // When - call twice
        await sut.setupInitialDataIfNeeded()
        let accountCountAfterFirst = mockRepository.accounts.count
        let categoryCountAfterFirst = mockRepository.categories.count

        await sut.setupInitialDataIfNeeded()

        // Then - counts should not change
        #expect(mockRepository.accounts.count == accountCountAfterFirst)
        #expect(mockRepository.categories.count == categoryCountAfterFirst)
    }

    @Test("setupInitialDataIfNeeded handles repository errors gracefully")
    func handlesRepositoryErrors() async throws {
        // Given - repository will throw on getAllAccounts
        mockRepository.shouldThrowError = true

        // When/Then - should complete without crashing
        await sut.setupInitialDataIfNeeded()

        // Method should have completed (no crash)
        #expect(true, "DataSeeder should handle errors gracefully without crashing")
    }
}
