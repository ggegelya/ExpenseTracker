//
//  DependencyContainer.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import CoreData

// MARK: - Dependency Container Protocol
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

// MARK: - Categorization Service

protocol CategorizationServiceProtocol {
    func suggestCategory(for description: String, merchantName: String?) async -> (category: Category?, confidence: Float)
    func learnFromCorrection(description: String, merchantName: String?, correctCategory: Category) async
}

final class CategorizationService: CategorizationServiceProtocol {
    private let repository: TransactionRepositoryProtocol
    
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
        
        // Try to find category by patterns
        for (pattern, categoryName) in merchantPatterns {
            if lowercasedDescription.contains(pattern) || lowercasedMerchant.contains(pattern) {
                do {
                    let categories = try await repository.getAllCategories()
                    if let category = categories.first(where: { $0.name == categoryName }) {
                        return (category, 0.85)
                    }
                } catch {
                    print("Failed to get categories: \(error)")
                }
            }
        }
        
        // Default to "інше" with low confidence
        do {
            let categories = try await repository.getAllCategories()
            if let defaultCategory = categories.first(where: { $0.name == "інше" }) {
                return (defaultCategory, 0.3)
            }
        } catch {
            print("Failed to get default category: \(error)")
        }
        
        return (nil, 0.0)
    }
    
    func learnFromCorrection(description: String, merchantName: String?, correctCategory: Category) async {
        // In a production app, this would update a Core ML model or
        // save the correction to improve future suggestions
        // For now, just log it
        print("Learning: '\(description)' -> \(correctCategory.name)")
    }
}

// MARK: - Analytics Service
// MARK: - Export Service

protocol ExportServiceProtocol {
    func exportToCSV(transactions: [Transaction]) async throws -> URL
    func exportToGoogleSheets(transactions: [Transaction]) async throws
}

final class ExportService: ExportServiceProtocol {
    private let repository: TransactionRepositoryProtocol
    
    init(repository: TransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    func exportToCSV(transactions: [Transaction]) async throws -> URL {
        // Create a unique, filesystem-safe filename with high precision timestamp and UUID
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = isoFormatter.string(from: Date()) // e.g., 2025-11-22T22:00:05.123Z

        // Sanitize characters that can be problematic in filenames on some systems
        let safeTimestamp = timestamp
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")

        let uniqueSuffix = UUID().uuidString
        let fileName = "transactions_\(safeTimestamp)_\(uniqueSuffix).csv"

        // Write to a dedicated subdirectory in the temporary directory to avoid conflicts
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        let fileURL = exportDir.appendingPathComponent(fileName)

        var csvText = "Date,Type,Amount,Category,Description,Account\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.transactionDate)
            let type = transaction.type.rawValue
            let amount = "\(transaction.amount)"
            let category = transaction.category?.name ?? ""
            let description = transaction.description.replacingOccurrences(of: ",", with: ";")
            let account = transaction.fromAccount?.name ?? transaction.toAccount?.name ?? ""

            csvText += "\(date),\(type),\(amount),\(category),\(description),\(account)\n"
        }

        try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    func exportToGoogleSheets(transactions: [Transaction]) async throws {
        // This would integrate with the existing Google Apps Script webhook
        // For now, just a placeholder
        print("Exporting \(transactions.count) transactions to Google Sheets")
    }
}

extension DependencyContainer {
    static func makeForTesting() -> DependencyContainer {
        return DependencyContainer(environment: .testing)
    }
    
    /// Synchronously creates a preview DependencyContainer and blocks until preview data is fully set up.
    /// This ensures that Core Data relationships are ready and available for SwiftUI previews.
    static func makeForPreviews() -> DependencyContainer {
        let container = DependencyContainer(environment: .preview)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await container.setupPreviewData()
            semaphore.signal()
        }
        semaphore.wait()
        return container
    }
}

