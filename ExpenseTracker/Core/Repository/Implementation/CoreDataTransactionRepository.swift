//
//  CoreDataTransactionRepository.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import CoreData
import Combine
import os

private let repositoryLogger = Logger(subsystem: "com.expensetracker", category: "Repository")

@MainActor
final class CoreDataTransactionRepository: TransactionRepositoryProtocol {
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    // Publishers
    private let transactionsSubject = CurrentValueSubject<[Transaction], Never>([])
    private let accountsSubject = CurrentValueSubject<[Account], Never>([])
    private let categoriesSubject = CurrentValueSubject<[Category], Never>([])

    private let shouldForcePublisherRefresh: Bool

    var transactionsPublisher: AnyPublisher<[Transaction], Never> {
        transactionsSubject.eraseToAnyPublisher()
    }

    var accountsPublisher: AnyPublisher<[Account], Never> {
        accountsSubject.eraseToAnyPublisher()
    }

    var categoriesPublisher: AnyPublisher<[Category], Never> {
        categoriesSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()
    private var isLoadingData = false

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
        self.shouldForcePublisherRefresh =
        ProcessInfo.processInfo.environment["IS_TESTING"] == "1" ||
        ProcessInfo.processInfo.environment["MOCK_DATA_ENABLED"] == "1" ||
        ProcessInfo.processInfo.arguments.contains("-UITesting")

        setupObservers()
        Task {
            await loadInitialData()
        }
    }

    /// Creates a fresh background context for each operation (thread safety)
    private func makeBackgroundContext() -> NSManagedObjectContext {
        persistenceController.container.newBackgroundContext()
    }

    private func setupObservers() {
        // Observe Core Data changes — only reload affected entity types
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleContextChange(notification)
                }
            }
            .store(in: &cancellables)
    }

    private func handleContextChange(_ notification: Notification) {
        let changedObjects = extractChangedObjects(from: notification)

        var needsTransactions = false
        var needsAccounts = false
        var needsCategories = false

        for object in changedObjects {
            switch object {
            case is TransactionEntity:
                needsTransactions = true
            case is AccountEntity:
                needsAccounts = true
            case is CategoryEntity:
                needsCategories = true
            case is PendingTransactionEntity:
                // Pending changes don't affect the main publishers
                break
            default:
                // Unknown entity — reload everything to be safe
                needsTransactions = true
                needsAccounts = true
                needsCategories = true
            }
            if needsTransactions && needsAccounts && needsCategories { break }
        }

        // Transaction changes may affect account balances
        if needsTransactions {
            needsAccounts = true
        }

        Task {
            await refreshPublishers(transactions: needsTransactions, accounts: needsAccounts, categories: needsCategories)
        }
    }

    private func extractChangedObjects(from notification: Notification) -> Set<NSManagedObject> {
        var objects = Set<NSManagedObject>()
        if let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            objects.formUnion(inserted)
        }
        if let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            objects.formUnion(updated)
        }
        if let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            objects.formUnion(deleted)
        }
        return objects
    }

    private func refreshPublishers(transactions: Bool, accounts: Bool, categories: Bool) async {
        guard !isLoadingData else { return }
        isLoadingData = true
        defer { isLoadingData = false }

        if transactions {
            do { transactionsSubject.send(try await getAllTransactions()) }
            catch { repositoryLogger.error("Failed to refresh transactions: \(error.localizedDescription)") }
        }
        if accounts {
            do { accountsSubject.send(try await getAllAccounts()) }
            catch { repositoryLogger.error("Failed to refresh accounts: \(error.localizedDescription)") }
        }
        if categories {
            do { categoriesSubject.send(try await getAllCategories()) }
            catch { repositoryLogger.error("Failed to refresh categories: \(error.localizedDescription)") }
        }
    }
    
    private func loadInitialData() async {
        await refreshPublishers(transactions: true, accounts: true, categories: true)
    }

    private func refreshPublishersIfNeeded() async {
        if shouldForcePublisherRefresh {
            await loadInitialData()
        }
    }
    
    // MARK: - Transaction Operations
    
    func createTransaction(_ transaction: Transaction) async throws -> Transaction {
        let created = try await performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextUnavailable }
            
            let entity = TransactionEntity(context: context)
            try self.updateEntity(entity, from: transaction, in: context)
            
            // Update account balances
            try self.updateAccountBalances(for: entity, isReversal: false, in: context)
            
            try context.save()
            
            // Fetch the saved transaction
            let savedEntity = try context.existingObject(with: entity.objectID) as? TransactionEntity
            guard let saved = savedEntity else { throw RepositoryError.entityNotFound }
            
            return try self.convertToTransaction(saved, includeSplits: true, in: context)
        }
        await refreshPublishersIfNeeded()
        return created
    }
    
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction {
        let updated = try await performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextUnavailable }
            
            let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            // Reverse old balances
            try self.updateAccountBalances(for: entity, isReversal: true, in: context)
            
            // Update entity
            try self.updateEntity(entity, from: transaction, in: context)
            
            // Apply new balances
            try self.updateAccountBalances(for: entity, isReversal: false, in: context)
            
            try context.save()
            
            return try self.convertToTransaction(entity, includeSplits: true, in: context)
        }
        await refreshPublishersIfNeeded()
        return updated
    }
    
    func deleteTransaction(_ transaction: Transaction) async throws {
        try await performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextUnavailable }
            
            let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            // If this is a split parent, reverse and delete all children first
            if let children = entity.splitTransactions as? Set<TransactionEntity>, !children.isEmpty {
                for child in children {
                    // Reverse child balances
                    try self.updateAccountBalances(for: child, isReversal: true, in: context)
                    // Delete child entity
                    context.delete(child)
                }
            }
            
            // Reverse balances for the entity itself before deletion
            try self.updateAccountBalances(for: entity, isReversal: true, in: context)
            
            // Delete the entity (parent or single transaction)
            context.delete(entity)
            try context.save()
        }
        await refreshPublishersIfNeeded()
    }
    
    func getTransaction(by id: UUID) async throws -> Transaction? {
        try await performOnViewContext { context in
            let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount"]

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            return try self.convertToTransaction(entity, includeSplits: true, in: context)
        }
    }
    
    func getAllTransactions() async throws -> [Transaction] {
        try await performOnViewContext { context in
            let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "parentTransaction == NIL")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \TransactionEntity.transactionDate, ascending: false),
                NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
            ]
            request.relationshipKeyPathsForPrefetching = [
                "category",
                "fromAccount",
                "toAccount",
                "splitTransactions",
                "splitTransactions.category"
            ]
            request.fetchBatchSize = 50

            let entities = try context.fetch(request)
            return try entities.compactMap { try self.convertToTransaction($0, includeSplits: true, in: context) }
        }
    }
    
    func getTransactions(for account: Account?,
                        in dateRange: ClosedRange<Date>?,
                        category: Category?) async throws -> [Transaction] {
        try await performOnViewContext { context in
            let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
            request.fetchBatchSize = 50
            var predicates: [NSPredicate] = [NSPredicate(format: "parentTransaction == NIL")]

            if let account = account {
                predicates.append(NSPredicate(
                    format: "fromAccount.id == %@ OR toAccount.id == %@",
                    account.id as CVarArg,
                    account.id as CVarArg
                ))
            }

            if let dateRange = dateRange {
                predicates.append(NSPredicate(
                    format: "transactionDate >= %@ AND transactionDate <= %@",
                    dateRange.lowerBound as NSDate,
                    dateRange.upperBound as NSDate
                ))
            }

            if let category = category {
                predicates.append(NSPredicate(
                    format: "category.id == %@",
                    category.id as CVarArg
                ))
            }

            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \TransactionEntity.transactionDate, ascending: false),
                NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
            ]
            request.relationshipKeyPathsForPrefetching = [
                "category",
                "fromAccount",
                "toAccount",
                "splitTransactions",
                "splitTransactions.category"
            ]

            let entities = try context.fetch(request)
            return try entities.compactMap { try self.convertToTransaction($0, includeSplits: true, in: context) }
        }
    }
    
    // MARK: - Pending Transaction Operations
    
    func createPendingTransaction(_ pending: PendingTransaction) async throws -> PendingTransaction {
        let created = try await performBackgroundTask { context in
            let entity = PendingTransactionEntity(context: context)
            entity.id = pending.id
            entity.bankTransactionId = pending.bankTransactionId
            entity.amount = NSDecimalNumber(decimal: pending.amount)
            entity.descriptionText = pending.descriptionText
            entity.merchantName = pending.merchantName
            entity.transactionDate = pending.transactionDate
            entity.type = pending.type.rawValue
            entity.confidence = pending.confidence
            entity.importedAt = pending.importedAt
            entity.status = pending.status.rawValue
            
            // Set account relationship
            if let accountEntity = try self.fetchAccountEntity(by: pending.account.id, in: context) {
                entity.account = accountEntity
            } else {
                repositoryLogger.warning("Account entity not found for pending transaction \(pending.id) — account relationship will be nil")
            }
            
            // Set suggested category relationship
            if let suggestedCategory = pending.suggestedCategory {
                entity.suggestedCategory = try self.fetchCategoryEntity(by: suggestedCategory.id, in: context)
            }
            
            try context.save()
            return pending
        }
        await refreshPublishersIfNeeded()
        return created
    }
    
    func getPendingTransactions(for account: Account?) async throws -> [PendingTransaction] {
        try await performOnViewContext { context in
            let request: NSFetchRequest<PendingTransactionEntity> = PendingTransactionEntity.fetchRequest()

            if let account = account {
                request.predicate = NSPredicate(format: "account.id == %@ AND status == %@",
                                               account.id as CVarArg,
                                               PendingTransaction.PendingStatus.pending.rawValue)
            } else {
                request.predicate = NSPredicate(format: "status == %@",
                                               PendingTransaction.PendingStatus.pending.rawValue)
            }

            request.sortDescriptors = [NSSortDescriptor(keyPath: \PendingTransactionEntity.transactionDate, ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["account", "suggestedCategory"]
            request.fetchBatchSize = 50

            let entities = try context.fetch(request)
            return entities.compactMap { self.convertToPendingTransactionSync($0, in: context) }
        }
    }
    
    func processPendingTransaction(_ pendingId: UUID, as transaction: Transaction) async throws {
        try await performBackgroundTask { context in
            // Find pending transaction
            let pendingRequest: NSFetchRequest<PendingTransactionEntity> = PendingTransactionEntity.fetchRequest()
            pendingRequest.predicate = NSPredicate(format: "id == %@", pendingId as CVarArg)
            pendingRequest.fetchLimit = 1
            
            guard let pendingEntity = try context.fetch(pendingRequest).first else {
                throw RepositoryError.entityNotFound
            }
            
            // Create actual transaction
            let transactionEntity = TransactionEntity(context: context)
            try self.updateEntity(transactionEntity, from: transaction, in: context)
            transactionEntity.bankTransactionId = pendingEntity.bankTransactionId
            transactionEntity.isReconciled = true
            
            // Update pending status
            pendingEntity.status = PendingTransaction.PendingStatus.processed.rawValue
            pendingEntity.processedAt = Date()
            
            // Update account balances
            try self.updateAccountBalances(for: transactionEntity, isReversal: false, in: context)
            
            try context.save()
        }
        await refreshPublishersIfNeeded()
    }
    
    func dismissPendingTransaction(_ pendingId: UUID) async throws {
        try await performBackgroundTask { context in
            let request: NSFetchRequest<PendingTransactionEntity> = PendingTransactionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", pendingId as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            entity.status = PendingTransaction.PendingStatus.dismissed.rawValue
            entity.processedAt = Date()
            
            try context.save()
        }
        await refreshPublishersIfNeeded()
    }
    
    // MARK: - Account Operations
    
    func createAccount(_ account: Account) async throws -> Account {
        let created = try await performBackgroundTask { context in
            // If this is set as default, unset other defaults first
            if account.isDefault {
                let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isDefault == true")
                let existingDefaults = try context.fetch(request)
                existingDefaults.forEach { $0.isDefault = false }
            }

            let entity = AccountEntity(context: context)
            entity.id = account.id
            entity.name = account.name
            entity.tag = account.tag
            entity.balance = NSDecimalNumber(decimal: account.balance)
            entity.isDefault = account.isDefault
            entity.type = account.accountType.rawValue
            entity.currency = account.currency.rawValue
            entity.createdAt = Date()

            try context.save()
            return Self.convertToAccount(entity)
        }
        await refreshPublishersIfNeeded()
        return created
    }
    
    func updateAccount(_ account: Account) async throws -> Account {
        let updated = try await performBackgroundTask { context in
            let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", account.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }

            entity.name = account.name
            entity.tag = account.tag
            entity.balance = NSDecimalNumber(decimal: account.balance)
            entity.type = account.accountType.rawValue
            entity.currency = account.currency.rawValue

            if account.isDefault && !entity.isDefault {
                // Setting as default — unset other defaults
                let defaultRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
                defaultRequest.predicate = NSPredicate(format: "isDefault == true AND id != %@", account.id as CVarArg)
                let existingDefaults = try context.fetch(defaultRequest)
                existingDefaults.forEach { $0.isDefault = false }
            }
            entity.isDefault = account.isDefault

            try context.save()
            return Self.convertToAccount(entity)
        }
        await refreshPublishersIfNeeded()
        return updated
    }
    
    func deleteAccount(_ account: Account) async throws {
        try await performBackgroundTask { context in
            let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", account.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }

            // Check if account has transactions
            let hasExpenses = (entity.expenseTransactions?.count ?? 0) > 0
            let hasIncome = (entity.incomeTransactions?.count ?? 0) > 0

            if hasExpenses || hasIncome {
                throw RepositoryError.conflictDetected(String(localized: "error.account.hasTransactions"))
            }

            context.delete(entity)
            try context.save()
        }
        await refreshPublishersIfNeeded()
    }
    
    func getAllAccounts() async throws -> [Account] {
        try await performOnViewContext { context in
            let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \AccountEntity.isDefault, ascending: false),
                NSSortDescriptor(keyPath: \AccountEntity.name, ascending: true)
            ]
            let entities = try context.fetch(request)
            return entities.map { Self.convertToAccount($0) }
        }
    }

    func getDefaultAccount() async throws -> Account? {
        try await performOnViewContext { context in
            let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDefault == true")
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            return Self.convertToAccount(entity)
        }
    }
    
    // MARK: - Category Operations
    
    func createCategory(_ category: Category) async throws -> Category {
        let created = try await performBackgroundTask { context in
            let entity = CategoryEntity(context: context)
            entity.id = category.id
            entity.name = category.name
            entity.icon = category.icon
            entity.colorHex = category.colorHex
            entity.isSystem = false
            entity.sortOrder = Int32(try context.count(for: CategoryEntity.fetchRequest()))

            try context.save()
            return Self.convertToCategory(entity)
        }
        await refreshPublishersIfNeeded()
        return created
    }

    func updateCategory(_ category: Category) async throws -> Category {
        let updated = try await performBackgroundTask { context in
            let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", category.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }

            entity.name = category.name
            entity.icon = category.icon
            entity.colorHex = category.colorHex

            try context.save()
            return Self.convertToCategory(entity)
        }
        await refreshPublishersIfNeeded()
        return updated
    }
    
    func deleteCategory(_ category: Category) async throws {
        try await performBackgroundTask { context in
            let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@ AND isSystem == false", category.id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            // Check if category has transactions
            if (entity.transactions?.count ?? 0) > 0 {
                throw RepositoryError.conflictDetected(String(localized: "error.category.hasTransactions"))
            }
            
            context.delete(entity)
            try context.save()
        }
        await refreshPublishersIfNeeded()
    }
    
    func getAllCategories() async throws -> [Category] {
        try await performOnViewContext { context in
            let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \CategoryEntity.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \CategoryEntity.name, ascending: true)
            ]
            let entities = try context.fetch(request)
            return entities.map { Self.convertToCategory($0) }
        }
    }
    
    // MARK: - Atomic Transaction Operations

    func performAtomicTransactionOperations(
        delete: [Transaction],
        update: [Transaction],
        create: [Transaction]
    ) async throws {
        try await performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextUnavailable }

            // 1. Delete
            // Build a set of IDs being deleted to avoid double balance reversal
            // when both parent and children are in the delete array
            let deleteIds = Set(delete.map { $0.id })

            for transaction in delete {
                let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
                request.fetchLimit = 1

                guard let entity = try context.fetch(request).first else {
                    throw RepositoryError.entityNotFound
                }

                // Delete children first if split parent
                if let children = entity.splitTransactions as? Set<TransactionEntity>, !children.isEmpty {
                    for child in children {
                        // Only reverse balance if child is not also in the delete array
                        // (avoids double reversal when caller includes both parent and children)
                        if let childId = child.id, !deleteIds.contains(childId) {
                            try self.updateAccountBalances(for: child, isReversal: true, in: context)
                        }
                        context.delete(child)
                    }
                }

                try self.updateAccountBalances(for: entity, isReversal: true, in: context)
                context.delete(entity)
            }

            // 2. Update
            for transaction in update {
                let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
                request.fetchLimit = 1

                guard let entity = try context.fetch(request).first else {
                    throw RepositoryError.entityNotFound
                }

                try self.updateAccountBalances(for: entity, isReversal: true, in: context)
                try self.updateEntity(entity, from: transaction, in: context)
                try self.updateAccountBalances(for: entity, isReversal: false, in: context)
            }

            // 3. Create
            for transaction in create {
                let entity = TransactionEntity(context: context)
                try self.updateEntity(entity, from: transaction, in: context)
                try self.updateAccountBalances(for: entity, isReversal: false, in: context)
            }

            // Single atomic save — rolls back on failure
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
        await refreshPublishersIfNeeded()
    }

    // MARK: - Batch Operations

    func performBatch(_ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        try await performBackgroundTask { context in
            do {
                try operation(context)
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
        await refreshPublishersIfNeeded()
    }
    
    // MARK: - Private Helpers
    
    private func performBackgroundTask<T>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = makeBackgroundContext()
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performOnViewContext<T>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = self.context
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private nonisolated func fetchAccountEntity(by id: UUID, in context: NSManagedObjectContext) throws -> AccountEntity? {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    private nonisolated func fetchCategoryEntity(by id: UUID, in context: NSManagedObjectContext) throws -> CategoryEntity? {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private nonisolated func fetchTransactionEntity(by id: UUID, in context: NSManagedObjectContext) throws -> TransactionEntity? {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    private nonisolated func updateEntity(_ entity: TransactionEntity,
                             from transaction: Transaction,
                             in context: NSManagedObjectContext) throws {
        entity.id = transaction.id
        entity.timestamp = transaction.timestamp
        entity.transactionDate = transaction.transactionDate
        entity.type = transaction.type.rawValue
        entity.amount = NSDecimalNumber(decimal: transaction.amount)
        entity.descriptionText = transaction.description
        entity.merchantName = transaction.merchantName
        
        // Set relationships
        if let category = transaction.category {
            entity.category = try fetchCategoryEntity(by: category.id, in: context)
        } else {
            entity.category = nil
        }
        
        if let fromAccount = transaction.fromAccount {
            entity.fromAccount = try fetchAccountEntity(by: fromAccount.id, in: context)
        } else {
            entity.fromAccount = nil
        }
        
        if let toAccount = transaction.toAccount {
            entity.toAccount = try fetchAccountEntity(by: toAccount.id, in: context)
        } else {
            entity.toAccount = nil
        }

        if let parentId = transaction.parentTransactionId {
            entity.parentTransaction = try fetchTransactionEntity(by: parentId, in: context)
        } else {
            entity.parentTransaction = nil
        }
    }
    
    private nonisolated func updateAccountBalances(for transaction: TransactionEntity,
                                      isReversal: Bool,
                                      in context: NSManagedObjectContext) throws {
        guard let type = transaction.type,
              let transactionType = TransactionType(rawValue: type),
              let amount = transaction.amount?.decimalValue else { return }
        
        let multiplier: Decimal = isReversal ? -1 : 1
        
        switch transactionType {
        case .expense, .transferOut:
            if let fromAccount = transaction.fromAccount {
                let currentBalance = fromAccount.balance?.decimalValue ?? 0
                fromAccount.balance = NSDecimalNumber(decimal: currentBalance - (amount * multiplier))
            }
        case .income, .transferIn:
            if let toAccount = transaction.toAccount {
                let currentBalance = toAccount.balance?.decimalValue ?? 0
                toAccount.balance = NSDecimalNumber(decimal: currentBalance + (amount * multiplier))
            }
        }
    }
    
    private nonisolated func convertToTransaction(_ entity: TransactionEntity,
                                     includeSplits: Bool,
                                     in context: NSManagedObjectContext) throws -> Transaction {
        guard let id = entity.id,
              let type = entity.type,
              let transactionType = TransactionType(rawValue: type),
              let amount = entity.amount?.decimalValue,
              let description = entity.descriptionText else {
            throw RepositoryError.invalidData(String(localized: "error.invalidTransactionData"))
        }

        let category = entity.category.map { Self.convertToCategory($0) }
        let fromAccount = entity.fromAccount.map { Self.convertToAccount($0) }
        let toAccount = entity.toAccount.map { Self.convertToAccount($0) }

        var splitTransactions: [Transaction]? = nil
        let shouldIncludeSplits = includeSplits && entity.parentTransaction == nil

        if shouldIncludeSplits,
           let childEntities = entity.splitTransactions as? Set<TransactionEntity>,
           !childEntities.isEmpty {
            let sortedChildren = childEntities.sorted { lhs, rhs in
                let lhsDate = lhs.transactionDate ?? lhs.timestamp ?? Date.distantPast
                let rhsDate = rhs.transactionDate ?? rhs.timestamp ?? Date.distantPast
                if lhsDate == rhsDate {
                    return (lhs.timestamp ?? lhsDate) < (rhs.timestamp ?? rhsDate)
                }
                return lhsDate < rhsDate
            }

            splitTransactions = try sortedChildren.map {
                try convertToTransaction($0, includeSplits: false, in: context)
            }
        }

        return Transaction(
            id: id,
            timestamp: entity.timestamp ?? Date(),
            transactionDate: entity.transactionDate ?? Date(),
            type: transactionType,
            amount: amount,
            category: category,
            description: description,
            merchantName: entity.merchantName,
            fromAccount: fromAccount,
            toAccount: toAccount,
            parentTransactionId: entity.parentTransaction?.id,
            splitTransactions: splitTransactions
        )
    }
    
    private nonisolated func convertToPendingTransactionSync(_ entity: PendingTransactionEntity, in context: NSManagedObjectContext) -> PendingTransaction? {
        guard let id = entity.id,
              let type = entity.type,
              let transactionType = TransactionType(rawValue: type),
              let amount = entity.amount?.decimalValue,
              let description = entity.descriptionText,
              let statusString = entity.status,
              let status = PendingTransaction.PendingStatus(rawValue: statusString),
              let accountEntity = entity.account else {
            return nil
        }

        let account = Self.convertToAccount(accountEntity)
        let suggestedCategory = entity.suggestedCategory.map { Self.convertToCategory($0) }

        return PendingTransaction(
            id: id,
            bankTransactionId: entity.bankTransactionId,
            amount: amount,
            descriptionText: description,
            merchantName: entity.merchantName,
            transactionDate: entity.transactionDate ?? Date(),
            type: transactionType,
            account: account,
            suggestedCategory: suggestedCategory,
            confidence: entity.confidence,
            importedAt: entity.importedAt ?? Date(),
            status: status
        )
    }

    // MARK: - Entity Conversion Helpers

    private nonisolated static func convertToAccount(_ entity: AccountEntity) -> Account {
        if entity.id == nil {
            repositoryLogger.warning("AccountEntity has nil id — fabricating UUID. This may indicate data corruption.")
        }
        return Account(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            tag: entity.tag ?? "",
            balance: entity.balance?.decimalValue ?? 0,
            isDefault: entity.isDefault,
            accountType: AccountType(rawValue: entity.type ?? "") ?? .card,
            currency: Currency(rawValue: entity.currency ?? "") ?? .uah
        )
    }

    private nonisolated static func convertToCategory(_ entity: CategoryEntity) -> Category {
        if entity.id == nil {
            repositoryLogger.warning("CategoryEntity has nil id — fabricating UUID. This may indicate data corruption.")
        }
        return Category(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            icon: entity.icon ?? "circle",
            colorHex: entity.colorHex ?? "#000000"
        )
    }
}
