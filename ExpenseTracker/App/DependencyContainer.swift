//
//  DependencyContainer.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import CoreData

// MARK: - Dependency Container Protocol
@MainActor
protocol DependencyContainerProtocol {
    var persistenceController: PersistenceController { get }
    var transactionRepository: TransactionRepositoryProtocol { get }
    var categorizationService: CategorizationServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var exportService: ExportServiceProtocol { get }
    
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
        
//        self.analyticsService = environment == .testing
//        ? MockAnalyticsService()
//        : AnalyticsService()
//        
        self.exportService = ExportService(
            repository: transactionRepository
        )
        
//        self.bankingService = environment == .testing
//        ? MockBankingService()
//        : BankingService(baseURL: environment.bankingBaseURL)
        
        // Setup initial data for non-testing environments
        if environment != .testing {
            Task {
                await setupInitialDataIfNeeded()
            }
        } else if TestingConfiguration.isRunningTests {
            // Seed predictable data for UI tests
            Task {
                await setupInitialDataIfNeeded()
                if !TestingConfiguration.shouldStartEmpty {
                    await setupPreviewData()
                }
            }
        }
    }
    
    // MARK: - Factory Methods
    
    @MainActor
    func makeTransactionViewModel() -> TransactionViewModel {
        return TransactionViewModel(
            repository: transactionRepository,
            categorizationService: categorizationService,
            analyticsService: analyticsService
        )
    }
    
    @MainActor
    func makeAccountsViewModel() -> AccountsViewModel {
        return AccountsViewModel(
            repository: transactionRepository,
            analyticsService: analyticsService
        )
    }
    
    @MainActor
    func makePendingTransactionsViewModel() -> PendingTransactionsViewModel {
        return PendingTransactionsViewModel(
            repository: transactionRepository,
            categorizationService: categorizationService,
            analyticsService: analyticsService
        )
    }

    @MainActor
    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        return AnalyticsViewModel(
            repository: transactionRepository
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
                    name: "Основна картка",
                    tag: "#main",
                    balance: 0,
                    isDefault: true
                )
                _ = try await transactionRepository.createAccount(defaultAccount)
            }
            
            // Check if we have categories
            let categories = try await transactionRepository.getAllCategories()
            if categories.isEmpty {
                // Create default categories
                let defaultCategories = [
                    Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50"),
                    Category(id: UUID(), name: "таксі", icon: "car.fill", colorHex: "#FFC107"),
                    Category(id: UUID(), name: "підписки", icon: "repeat", colorHex: "#9C27B0"),
                    Category(id: UUID(), name: "комуналка", icon: "house.fill", colorHex: "#2196F3"),
                    Category(id: UUID(), name: "аптека", icon: "cross.case.fill", colorHex: "#F44336"),
                    Category(id: UUID(), name: "кафе", icon: "cup.and.saucer.fill", colorHex: "#FF9800"),
                    Category(id: UUID(), name: "одяг", icon: "tshirt.fill", colorHex: "#E91E63"),
                    Category(id: UUID(), name: "розваги", icon: "gamecontroller.fill", colorHex: "#00BCD4"),
                    Category(id: UUID(), name: "транспорт", icon: "bus.fill", colorHex: "#795548"),
                    Category(id: UUID(), name: "подарунки", icon: "gift.fill", colorHex: "#FF5722"),
                    Category(id: UUID(), name: "навчання", icon: "book.fill", colorHex: "#3F51B5"),
                    Category(id: UUID(), name: "спорт", icon: "figure.run", colorHex: "#4CAF50"),
                    Category(id: UUID(), name: "краса", icon: "sparkles", colorHex: "#E91E63"),
                    Category(id: UUID(), name: "техніка", icon: "desktopcomputer", colorHex: "#607D8B"),
                    Category(id: UUID(), name: "інше", icon: "ellipsis.circle.fill", colorHex: "#9E9E9E")
                ]
                
                for category in defaultCategories {
                    _ = try await transactionRepository.createCategory(category)
                }
            }
        } catch {
            print("Failed to setup initial data: \(error)")
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
                let groceries = categories.first { $0.name == "продукти" }
                let transport = categories.first { $0.name == "транспорт" }
                let cafe = categories.first { $0.name == "кафе" }

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
                    suggestedCategory: categories.first { $0.name == "продукти" },
                    confidence: 0.85,
                    importedAt: Date(),
                    status: .pending
                )
                
                _ = try await transactionRepository.createPendingTransaction(pending)
            }
            
        } catch {
            print("Failed to setup preview data: \(error)")
        }
    }
    
    private func generateSampleDescription(for category: Category?, isExpense: Bool) -> String {
        guard let category = category else { return "Інша операція" }
        
        let descriptions: [String: [String]] = [
            "продукти": ["Сільпо", "АТБ", "Фора", "Метро", "Novus"],
            "таксі": ["Uber", "Bolt", "Uklon", "Таксі по місту"],
            "підписки": ["Netflix", "Spotify", "Apple Music", "YouTube Premium"],
            "комуналка": ["Київводоканал", "Київенерго", "Київгаз", "Інтернет"],
            "аптека": ["Аптека Доброго Дня", "Аптека 911", "Аптека Низьких Цін"],
            "кафе": ["Aroma Kava", "Starbucks", "Львівська майстерня шоколаду", "One Love"],
            "одяг": ["Zara", "H&M", "Reserved", "Bershka", "Pull&Bear"],
            "розваги": ["Кінотеатр", "Боулінг", "Квест кімната", "Концерт"],
            "транспорт": ["Метро", "Маршрутка", "Автобус", "Трамвай"],
            "подарунки": ["Подарунок на день народження", "Новорічний подарунок", "Сувенір"],
            "навчання": ["Курси англійської", "Онлайн курс", "Книги", "Підручники"],
            "спорт": ["Спортзал", "Басейн", "Йога", "Тренер"],
            "краса": ["Перукарня", "Манікюр", "Косметика", "SPA"],
            "техніка": ["Rozetka", "Фокстрот", "Алло", "Comfy"]
        ]
        
        if !isExpense {
            let incomeDescriptions = ["Зарплата", "Фріланс", "Повернення боргу", "Кешбек", "Подарунок"]
            return incomeDescriptions.randomElement() ?? "Надходження"
        }
        
        let categoryDescriptions = descriptions[category.name] ?? ["Оплата"]
        return categoryDescriptions.randomElement() ?? "Витрата"
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
            ("продукти", "cart.fill", "#4CAF50"),
            ("таксі", "car.fill", "#FFC107"),
            ("кафе", "cup.and.saucer.fill", "#FF9800"),
            ("інше", "ellipsis.circle.fill", "#9E9E9E")
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
