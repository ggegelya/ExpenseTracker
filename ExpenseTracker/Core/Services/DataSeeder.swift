//
//  DataSeeder.swift
//  ExpenseTracker
//
//  Extracted from DependencyContainer. Handles initial data setup
//  (default account + categories) and preview/test data seeding.
//

import Foundation
import os

private let seederLogger = Logger(subsystem: "com.expensetracker", category: "DataSeeder")

@MainActor
final class DataSeeder {
    private let repository: TransactionRepositoryProtocol

    init(repository: TransactionRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Initial Data

    func setupInitialDataIfNeeded() async {
        do {
            // Check if we have any accounts
            let accounts = try await repository.getAllAccounts()
            if accounts.isEmpty {
                let defaultAccount = Account(
                    id: UUID(),
                    name: "default_card",
                    tag: "#main",
                    balance: 0,
                    isDefault: true
                )
                _ = try await repository.createAccount(defaultAccount)
            }

            // Check if we have categories
            let categories = try await repository.getAllCategories()
            if categories.isEmpty {
                for category in Category.defaults {
                    _ = try await repository.createCategory(category)
                }
            }
        } catch {
            seederLogger.error("Failed to setup initial data: \(error.localizedDescription)")
        }
    }

    // MARK: - Preview / Test Data

    func setupPreviewData() async {
        if TestingConfiguration.isRunningTests || TestingConfiguration.shouldUseMockData {
            await setupTestData()
            return
        }

        await setupFullPreviewData()
    }

    private func createPreviewAccounts() async throws -> (main: Account, savings: Account) {
        let mainAccount = Account(id: UUID(), name: "Монобанк", tag: "#mono", balance: 15000, isDefault: true)
        let savingsAccount = Account(id: UUID(), name: "Заощадження", tag: "#savings", balance: 50000, isDefault: false)
        _ = try await repository.createAccount(mainAccount)
        _ = try await repository.createAccount(savingsAccount)
        return (mainAccount, savingsAccount)
    }

    private func setupTestData() async {
        do {
            let (mainAccount, _) = try await createPreviewAccounts()

            let categories = try await repository.getAllCategories()
            let groceries = categories.first { $0.name == "groceries" }
            let transport = categories.first { $0.name == "transport" }
            let cafe = categories.first { $0.name == "cafe" }

            let calendar = Calendar.current
            let now = Date()

            let transactions: [Transaction] = [
                Transaction(
                    transactionDate: now,
                    type: .expense,
                    amount: 250,
                    category: groceries,
                    description: "Сільпо",
                    fromAccount: mainAccount,
                    toAccount: nil
                ),
                Transaction(
                    transactionDate: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                    type: .expense,
                    amount: 80,
                    category: transport,
                    description: "Метро",
                    fromAccount: mainAccount,
                    toAccount: nil
                ),
                Transaction(
                    transactionDate: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                    type: .expense,
                    amount: 120,
                    category: cafe,
                    description: "Aroma Kava",
                    fromAccount: mainAccount,
                    toAccount: nil
                ),
                Transaction(
                    transactionDate: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                    type: .income,
                    amount: 2000,
                    category: nil,
                    description: "Зарплата",
                    fromAccount: nil,
                    toAccount: mainAccount
                )
            ]

            for transaction in transactions {
                _ = try await repository.createTransaction(transaction)
            }

            let pending = PendingTransaction(
                id: UUID(),
                bankTransactionId: "MONO000001",
                amount: 150,
                descriptionText: "Термінал Сільпо",
                merchantName: "SILPO MARKET",
                transactionDate: now,
                type: .expense,
                account: mainAccount,
                suggestedCategory: groceries,
                confidence: 0.85,
                importedAt: now,
                status: .pending
            )
            _ = try await repository.createPendingTransaction(pending)
        } catch {
            seederLogger.error("Failed to setup test data: \(error.localizedDescription)")
        }
    }

    private func setupFullPreviewData() async {
        do {
            let (mainAccount, _) = try await createPreviewAccounts()

            // Get categories
            let categories = try await repository.getAllCategories()

            // Create sample transactions for the last 30 days
            let calendar = Calendar.current
            let now = Date()

            for dayOffset in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

                let transactionCount = Int.random(in: 0...3)

                for _ in 0..<transactionCount {
                    let isExpense = Double.random(in: 0...1) > 0.2
                    let category = categories.randomElement()
                    let amount = Decimal(Double.random(in: 20...500))

                    let transaction = Transaction(
                        transactionDate: date,
                        type: isExpense ? .expense : .income,
                        amount: amount,
                        category: category,
                        description: generateSampleDescription(for: category, isExpense: isExpense),
                        fromAccount: isExpense ? mainAccount : nil,
                        toAccount: isExpense ? nil : mainAccount
                    )

                    _ = try await repository.createTransaction(transaction)
                }
            }

            // Create pending transactions (banking queue)
            for i in 0..<5 {
                let pending = PendingTransaction(
                    id: UUID(),
                    bankTransactionId: "MONO\(String(format: "%06d", i))",
                    amount: Decimal(Double.random(in: 50...300)),
                    descriptionText: "Термінал Сільпо",
                    merchantName: "SILPO MARKET",
                    transactionDate: calendar.date(byAdding: .day, value: -i, to: now) ?? now,
                    type: .expense,
                    account: mainAccount,
                    suggestedCategory: categories.first { $0.name == "groceries" },
                    confidence: 0.85,
                    importedAt: Date(),
                    status: .pending
                )

                _ = try await repository.createPendingTransaction(pending)
            }
        } catch {
            seederLogger.error("Failed to setup preview data: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static let sampleDescriptions: [String: [String]] = [
        "groceries": ["Сільпо", "АТБ", "Фора", "Метро", "Novus"],
        "taxi": ["Uber", "Bolt", "Uklon"],
        "subscriptions": ["Netflix", "Spotify", "Apple Music", "YouTube Premium"],
        "utilities": ["Київводоканал", "Київенерго", "Київгаз"],
        "pharmacy": ["Аптека Доброго Дня", "Аптека 911"],
        "cafe": ["Aroma Kava", "Starbucks", "One Love"],
        "clothing": ["Zara", "H&M", "Reserved", "Bershka"],
        "entertainment": ["Кінотеатр", "Боулінг", "Концерт"],
        "transport": ["Метро", "Маршрутка", "Автобус"],
        "gifts": ["Подарунок", "Сувенір"],
        "education": ["Курси", "Книги"],
        "sports": ["Спортзал", "Басейн", "Йога"],
        "beauty": ["Перукарня", "Манікюр", "SPA"],
        "electronics": ["Rozetka", "Фокстрот", "Comfy"]
    ]

    private func generateSampleDescription(for category: Category?, isExpense: Bool) -> String {
        guard let category = category else { return "Інше" }

        if !isExpense {
            let incomeDescriptions = ["Зарплата", "Фріланс", "Кешбек"]
            return incomeDescriptions.randomElement() ?? "Дохід"
        }

        let categoryDescriptions = Self.sampleDescriptions[category.name] ?? ["Оплата"]
        return categoryDescriptions.randomElement() ?? "Витрата"
    }
}
