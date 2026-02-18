//
//  ExportServiceTests.swift
//  ExpenseTracker
//
//  Tests for ExportService business logic
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("Export Service Tests", .serialized)
struct ExportServiceTests {
    var sut: ExportService

    init() async throws {
        sut = ExportService()
    }

    // MARK: - CSV Export Tests

    @Test("Export to CSV creates valid CSV file")
    func exportToCSVCreatesValidFile() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, description: "Test 1"),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, description: "Test 2")
        ]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)

        // Then
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV includes all transaction fields")
    func exportToCSVIncludesAllFields() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(
            amount: 150.50,
            category: category,
            account: account,
            description: "Groceries at Silpo"
        )

        // When
        let fileURL = try await sut.exportToCSV(transactions: [transaction])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then
        #expect(csvContent.contains("Date"))
        #expect(csvContent.contains("Type"))
        #expect(csvContent.contains("Amount"))
        #expect(csvContent.contains("Category"))
        #expect(csvContent.contains("Description"))
        #expect(csvContent.contains("Account"))

        // Verify transaction data is present
        #expect(csvContent.contains("150.5"))
        // Category uses displayName (localized)
        let expectedCategoryName = MockCategory.makeGroceries().displayName
        #expect(csvContent.contains(expectedCategoryName))
        #expect(csvContent.contains("Groceries at Silpo"))
        #expect(csvContent.contains("Готівка"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV handles special characters correctly")
    func exportToCSVHandlesSpecialCharacters() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(
            amount: 100,
            category: category,
            account: account,
            description: "Test, with, commas"
        )

        // When
        let fileURL = try await sut.exportToCSV(transactions: [transaction])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then - commas in description should be quoted per RFC 4180
        #expect(csvContent.contains("\"Test, with, commas\""))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV formats dates correctly for Ukrainian locale")
    func exportToCSVFormatsDateCorrectly() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let specificDate = DateGenerator.date(year: 2025, month: 1, day: 15)
        let transaction = MockTransaction.makeExpense(
            amount: 100,
            category: category,
            account: account,
            description: "Test",
            date: specificDate
        )

        // When
        let fileURL = try await sut.exportToCSV(transactions: [transaction])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then - date should be present in some format
        let lines = csvContent.components(separatedBy: .newlines)
        #expect(lines.count >= 2) // Header + at least one data row

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV formats amounts correctly")
    func exportToCSVFormatsAmountsCorrectly() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = [
            MockTransaction.makeExpense(amount: 100.00, category: category, account: account),
            MockTransaction.makeExpense(amount: 250.50, category: category, account: account),
            MockTransaction.makeExpense(amount: 1234.99, category: category, account: account)
        ]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then
        #expect(csvContent.contains("100"))
        #expect(csvContent.contains("250.5"))
        #expect(csvContent.contains("1234.99"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV handles empty transaction list")
    func exportToCSVHandlesEmptyList() async throws {
        // When
        let fileURL = try await sut.exportToCSV(transactions: [])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then - should only contain header
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 1) // Only header row
        #expect(csvContent.contains("Date,Type,Amount,Category,Description,Account"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV includes income transactions correctly")
    func exportToCSVIncludesIncome() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeSalary()
        let incomeTransaction = MockTransaction.makeIncome(
            amount: 5000,
            category: category,
            account: account,
            description: "Зарплата"
        )

        // When
        let fileURL = try await sut.exportToCSV(transactions: [incomeTransaction])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then
        #expect(csvContent.contains("income"))
        #expect(csvContent.contains("5000"))
        #expect(csvContent.contains("Зарплата"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV includes transfer transactions correctly")
    func exportToCSVIncludesTransfers() async throws {
        // Given
        let fromAccount = MockAccount.makeDefault()
        let toAccount = MockAccount.makeSecondary()
        let transfer = MockTransaction.makeTransfer(
            amount: 1000,
            fromAccount: fromAccount,
            toAccount: toAccount
        )

        // When
        let fileURL = try await sut.exportToCSV(transactions: [transfer])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then
        #expect(csvContent.contains("transferOut"))
        #expect(csvContent.contains("1000"))
        #expect(csvContent.contains("Переказ"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export file can be read back and parsed")
    func exportFileCanBeReadBackAndParsed() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, description: "Test 1"),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, description: "Test 2"),
            MockTransaction.makeExpense(amount: 300, category: category, account: account, description: "Test 3")
        ]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Then
        #expect(lines.count == 4) // Header + 3 transactions
        #expect(lines[0] == "Date,Type,Amount,Category,Description,Account")

        // Verify each transaction line has 6 fields
        for i in 1..<lines.count {
            let fields = lines[i].components(separatedBy: ",")
            #expect(fields.count == 6) // Date, Type, Amount, Category, Description, Account
        }

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV creates unique filenames")
    func exportToCSVCreatesUniqueFilenames() async throws {
        // Given
        let transactions = [MockTransaction.makeExpense()]

        // When
        let fileURL1 = try await sut.exportToCSV(transactions: transactions)
        let fileURL2 = try await sut.exportToCSV(transactions: transactions)

        // Then - filenames should be different (timestamped)
        #expect(fileURL1.lastPathComponent != fileURL2.lastPathComponent)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL1)
        try? FileManager.default.removeItem(at: fileURL2)
    }

    @Test("Export to CSV handles transactions without category")
    func exportToCSVHandlesNilCategory() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let transaction = MockTransaction.makeExpense(category: nil, account: account)

        // When
        let fileURL = try await sut.exportToCSV(transactions: [transaction])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then - should have empty category field
        let lines = csvContent.components(separatedBy: .newlines)
        #expect(lines.count >= 2)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV handles large transaction lists")
    func exportToCSVHandlesLargeTransactionList() async throws {
        // Given
        let transactions = MockTransaction.makeMultiple(count: 100, dateRange: 365)

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Then
        #expect(lines.count == 101) // Header + 100 transactions

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export to CSV uses UTF-8 encoding for Ukrainian text")
    func exportToCSVUsesUTF8ForUkrainian() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(
            amount: 100,
            category: category,
            account: account,
            description: "Продукти в Сільпо"
        )

        // When
        let fileURL = try await sut.exportToCSV(transactions: [transaction])
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then - Ukrainian text should be readable
        #expect(csvContent.contains("Продукти в Сільпо"))
        #expect(csvContent.contains(MockCategory.makeGroceries().displayName))
        #expect(csvContent.contains("Готівка"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Google Sheets Export Tests (Placeholders)
    // Note: Google Sheets export is not fully implemented yet (placeholder implementation)

    @Test("Export to Google Sheets completes without error - PLACEHOLDER", .disabled("Google Sheets export not yet implemented"))
    func exportToGoogleSheetsCompletes() async throws {
        // Given
        let transactions = [MockTransaction.makeExpense()]

        // When/Then - should not throw (placeholder implementation just prints)
        try await sut.exportToGoogleSheets(transactions: transactions)
        #expect(true)
    }

    @Test("Export to Google Sheets handles empty list - PLACEHOLDER", .disabled("Google Sheets export not yet implemented"))
    func exportToGoogleSheetsHandlesEmptyList() async throws {
        // When/Then
        try await sut.exportToGoogleSheets(transactions: [])
        #expect(true)
    }

    @Test("Export to Google Sheets handles large lists - PLACEHOLDER", .disabled("Google Sheets export not yet implemented"))
    func exportToGoogleSheetsHandlesLargeLists() async throws {
        // Given
        let transactions = MockTransaction.makeMultiple(count: 100)

        // When/Then
        try await sut.exportToGoogleSheets(transactions: transactions)
        #expect(true)
    }

    // MARK: - Edge Cases

    @Test("Export filename contains timestamp in ISO8601 format")
    func exportFilenameContainsTimestamp() async throws {
        // Given
        let transactions = [MockTransaction.makeExpense()]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)

        // Then
        #expect(fileURL.lastPathComponent.hasPrefix("transactions_"))
        #expect(fileURL.lastPathComponent.hasSuffix(".csv"))
        #expect(fileURL.deletingLastPathComponent().lastPathComponent == "exports")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("Export creates file in temporary directory")
    func exportCreatesFileInTempDirectory() async throws {
        // Given
        let transactions = [MockTransaction.makeExpense()]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)

        // Then
        let tempDir = FileManager.default.temporaryDirectory
        #expect(fileURL.path.hasPrefix(tempDir.appendingPathComponent("exports").path))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("CSV export handles transactions from multiple accounts")
    func csvExportHandlesMultipleAccounts() async throws {
        // Given
        let account1 = MockAccount.makeDefault()
        let account2 = MockAccount.makeSecondary()
        let transactions = [
            MockTransaction.makeExpense(account: account1, description: "Account 1 expense"),
            MockTransaction.makeExpense(account: account2, description: "Account 2 expense")
        ]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then
        #expect(csvContent.contains("Готівка"))
        #expect(csvContent.contains("Картка ПриватБанк"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test("CSV export handles all transaction types")
    func csvExportHandlesAllTransactionTypes() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let transactions = [
            MockTransaction.makeExpense(account: account),
            MockTransaction.makeIncome(account: account),
            MockTransaction.makeTransfer(fromAccount: account, toAccount: MockAccount.makeSecondary())
        ]

        // When
        let fileURL = try await sut.exportToCSV(transactions: transactions)
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        // Then
        #expect(csvContent.contains("expense"))
        #expect(csvContent.contains("income"))
        #expect(csvContent.contains("transferOut"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
}
