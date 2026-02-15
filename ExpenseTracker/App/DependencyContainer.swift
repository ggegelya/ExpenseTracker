//
//  DependencyContainer.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import CoreData
import os

private let containerLogger = Logger(subsystem: "com.expensetracker", category: "DependencyContainer")

// MARK: - Dependency Container Protocol
@MainActor
protocol DependencyContainerProtocol {
    var persistenceController: PersistenceController { get }
    var transactionRepository: TransactionRepositoryProtocol { get }
    var categorizationService: CategorizationServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var exportService: ExportServiceProtocol { get }
    var errorHandlingService: ErrorHandlingServiceProtocol { get }

    // ViewModels
    @MainActor func makeTransactionViewModel() -> TransactionViewModel
    @MainActor func makeAccountsViewModel() -> AccountsViewModel
    @MainActor func makePendingTransactionsViewModel() -> PendingTransactionsViewModel
    @MainActor func makeAnalyticsViewModel() -> AnalyticsViewModel
}

// MARK: - Production Dependency Container
@MainActor
final class DependencyContainer: DependencyContainerProtocol {
    let environment: AppEnvironment
    let persistenceController: PersistenceController
    let transactionRepository: TransactionRepositoryProtocol
    let categorizationService: CategorizationServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let exportService: ExportServiceProtocol
    let errorHandlingService: ErrorHandlingServiceProtocol

    /// Task that completes when initial data setup is finished.
    private(set) var setupTask: Task<Void, Never>?

    init(environment: AppEnvironment = .production) {
        self.environment = environment
        // Initialize persistence
        self.persistenceController = PersistenceController(inMemory: environment.usesInMemoryStore)

        // Initialize repositories
        self.transactionRepository = CoreDataTransactionRepository(
            persistenceController: persistenceController
        )

        // Initialize services
        self.categorizationService = CategorizationService(
            repository: transactionRepository
        )

        self.analyticsService = AnalyticsService()

        self.exportService = ExportService()

        self.errorHandlingService = ErrorHandlingService(
            analyticsService: analyticsService
        )

        // Setup initial data — store the task so callers can await it
        if environment != .testing {
            setupTask = Task {
                await setupInitialDataIfNeeded()
            }
        } else if TestingConfiguration.isRunningTests {
            setupTask = Task {
                await setupInitialDataIfNeeded()
                if !TestingConfiguration.shouldStartEmpty {
                    await setupPreviewData()
                }
            }
        }
    }

    /// Awaits initial data setup completion. Safe to call multiple times.
    func ensureReady() async {
        await setupTask?.value
    }
    
    // MARK: - Factory Methods
    
    @MainActor
    func makeTransactionViewModel() -> TransactionViewModel {
        return TransactionViewModel(
            repository: transactionRepository,
            categorizationService: categorizationService,
            analyticsService: analyticsService,
            errorHandler: errorHandlingService
        )
    }

    @MainActor
    func makeAccountsViewModel() -> AccountsViewModel {
        return AccountsViewModel(
            repository: transactionRepository,
            analyticsService: analyticsService,
            errorHandler: errorHandlingService
        )
    }

    @MainActor
    func makePendingTransactionsViewModel() -> PendingTransactionsViewModel {
        return PendingTransactionsViewModel(
            repository: transactionRepository,
            categorizationService: categorizationService,
            analyticsService: analyticsService,
            errorHandler: errorHandlingService
        )
    }

    @MainActor
    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        return AnalyticsViewModel(
            repository: transactionRepository,
            errorHandler: errorHandlingService
        )
    }

    func cleanup() async {
        // cleanup services, etc.
        // await bankingService.disconnect()
    }
    
    // MARK: - Setup Methods
    
    private func setupInitialDataIfNeeded() async {
        do {
            // Check if we have any accounts
            let accounts = try await transactionRepository.getAllAccounts()
            if accounts.isEmpty {
                // Create default account
                let defaultAccount = Account(
                    id: UUID(),
                    name: "default_card",
                    tag: "#main",
                    balance: 0,
                    isDefault: true
                )
                _ = try await transactionRepository.createAccount(defaultAccount)
            }
            
            // Check if we have categories
            let categories = try await transactionRepository.getAllCategories()
            if categories.isEmpty {
                for category in Category.defaults {
                    _ = try await transactionRepository.createCategory(category)
                }
            }
        } catch {
            containerLogger.error("Failed to setup initial data: \(error.localizedDescription)")
        }
    }
    
    private func setupPreviewData() async {
        do {
            if TestingConfiguration.isRunningTests || TestingConfiguration.shouldUseMockData {
                let mainAccount = Account(id: UUID(), name: "Монобанк", tag: "#mono", balance: 15000, isDefault: true)
                let savingsAccount = Account(id: UUID(), name: "Заощадження", tag: "#savings", balance: 50000, isDefault: false)

                _ = try await transactionRepository.createAccount(mainAccount)
                _ = try await transactionRepository.createAccount(savingsAccount)

                let categories = try await transactionRepository.getAllCategories()
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
                    _ = try await transactionRepository.createTransaction(transaction)
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
                _ = try await transactionRepository.createPendingTransaction(pending)
                return
            }

            // Create accounts
            let mainAccount = Account(id: UUID(), name: "Монобанк", tag: "#mono", balance: 15000, isDefault: true)
            let savingsAccount = Account(id: UUID(), name: "Заощадження", tag: "#savings", balance: 50000, isDefault: false)
            
            _ = try await transactionRepository.createAccount(mainAccount)
            _ = try await transactionRepository.createAccount(savingsAccount)
            
            // Get categories
            let categories = try await transactionRepository.getAllCategories()
            
            // Create sample transactions
            let calendar = Calendar.current
            let now = Date()
            
            // Sample transactions for the last 30 days
            for dayOffset in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
                
                // Random 0-3 transactions per day
                let transactionCount = Int.random(in: 0...3)
                
                for _ in 0..<transactionCount {
                    let isExpense = Double.random(in: 0...1) > 0.2 // 80% expenses
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
                    
                    _ = try await transactionRepository.createTransaction(transaction)
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
                
                _ = try await transactionRepository.createPendingTransaction(pending)
            }
            
        } catch {
            containerLogger.error("Failed to setup preview data: \(error.localizedDescription)")
        }
    }
    
    private func generateSampleDescription(for category: Category?, isExpense: Bool) -> String {
        guard let category = category else { return "Other" }
        
        let descriptions: [String: [String]] = [
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
        
        if !isExpense {
            let incomeDescriptions = ["Salary", "Freelance", "Cashback"]
            return incomeDescriptions.randomElement() ?? "Income"
        }

        let categoryDescriptions = descriptions[category.name] ?? ["Payment"]
        return categoryDescriptions.randomElement() ?? "Expense"
    }
}

extension DependencyContainer {
    static func makeForTesting() -> DependencyContainer {
        return DependencyContainer(environment: .testing)
    }
    
    /// Creates a preview DependencyContainer with synchronously seeded data on viewContext.
    /// No async/semaphore needed — preview data is inserted directly.
    static func makeForPreviews() -> DependencyContainer {
        let container = DependencyContainer(environment: .preview)
        container.seedPreviewDataSync()
        return container
    }

    private func seedPreviewDataSync() {
        let viewContext = persistenceController.container.viewContext

        // Create accounts
        let mainAccount = AccountEntity(context: viewContext)
        mainAccount.id = UUID()
        mainAccount.name = "Монобанк"
        mainAccount.tag = "#mono"
        mainAccount.balance = NSDecimalNumber(decimal: 15000)
        mainAccount.isDefault = true
        mainAccount.createdAt = Date()

        let savingsAccount = AccountEntity(context: viewContext)
        savingsAccount.id = UUID()
        savingsAccount.name = "Заощадження"
        savingsAccount.tag = "#savings"
        savingsAccount.balance = NSDecimalNumber(decimal: 50000)
        savingsAccount.isDefault = false
        savingsAccount.createdAt = Date()

        // Create categories
        let categoryData: [(String, String, String)] = [
            ("groceries", "cart.fill", "#4CAF50"),
            ("taxi", "car.fill", "#FFC107"),
            ("cafe", "cup.and.saucer.fill", "#FF9800"),
            ("other", "ellipsis.circle.fill", "#9E9E9E")
        ]

        var categoryEntities: [CategoryEntity] = []
        for (index, (name, icon, color)) in categoryData.enumerated() {
            let entity = CategoryEntity(context: viewContext)
            entity.id = UUID()
            entity.name = name
            entity.icon = icon
            entity.colorHex = color
            entity.isSystem = true
            entity.sortOrder = Int32(index)
            categoryEntities.append(entity)
        }

        // Create sample transactions
        let calendar = Calendar.current
        let now = Date()
        for dayOffset in 0..<5 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let transaction = TransactionEntity(context: viewContext)
            transaction.id = UUID()
            transaction.timestamp = date
            transaction.transactionDate = date
            transaction.type = TransactionType.expense.rawValue
            transaction.amount = NSDecimalNumber(decimal: Decimal(Double.random(in: 50...500)))
            transaction.descriptionText = "Покупка \(dayOffset + 1)"
            transaction.category = categoryEntities[dayOffset % categoryEntities.count]
            transaction.fromAccount = mainAccount
        }

        try? viewContext.save()
    }
}
