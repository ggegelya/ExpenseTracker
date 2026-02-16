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

    /// Concrete ErrorHandlingService instance for SwiftUI environmentObject injection.
    let errorHandlingServiceInstance: ErrorHandlingService

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

        let errorService = ErrorHandlingService(
            analyticsService: analyticsService
        )
        self.errorHandlingService = errorService
        self.errorHandlingServiceInstance = errorService

        // Setup initial data — store the task so callers can await it
        let seeder = DataSeeder(repository: transactionRepository)
        if environment != .testing {
            setupTask = Task {
                let migrationService = CategoryMigrationService(repository: transactionRepository)
                await migrationService.migrateIfNeeded()
                await seeder.setupInitialDataIfNeeded()
                // Invalidate category cache after migration may have renamed categories
                categorizationService.invalidateCategoryCache()
            }
        } else if TestingConfiguration.isRunningTests {
            setupTask = Task {
                await seeder.setupInitialDataIfNeeded()
                if !TestingConfiguration.shouldStartEmpty {
                    await seeder.setupPreviewData()
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
