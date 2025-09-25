//
//  CoreDataTransactionRepository.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import CoreData
import Combine

final class CoreDataTransactionRepository: TransactionRepositoryProtocol {
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    
    // Publishers
    private let transactionsSubject = CurrentValueSubject<[Transaction], Never>([])
    private let accountsSubject = CurrentValueSubject<[Account], Never>([])
    private let categoriesSubject = CurrentValueSubject<[Category], Never>([])
    
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
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        
        setupObservers()
        Task {
            await loadInitialData()
        }
    }
    
    private func setupObservers() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() async {
        do {
            async let transactions = getAllTransactions()
            async let accounts = getAllAccounts()
            async let categories = getAllCategories()
            
            let (loadedTransactions, loadedAccounts, loadedCategories) = try await (transactions, accounts, categories)
            
            transactionsSubject.send(loadedTransactions)
            accountsSubject.send(loadedAccounts)
            categoriesSubject.send(loadedCategories)
        } catch {
            print("Failed to load initial data: \(error)")
        }
    }
    
    // MARK: - Transaction Operations
    
    func createTransaction(_ transaction: Transaction) async throws -> Transaction {
        return try await performBackgroundTask { [weak self] context in
            guard let self = self else { throw RepositoryError.contextUnavailable }
            
            let entity = TransactionEntity(context: context)
            try self.updateEntity(entity, from: transaction, in: context)
            
            // Update account balances
            try self.updateAccountBalances(for: entity, isReversal: false, in: context)
            
            try context.save()
            
            // Fetch the saved transaction
            let savedEntity = try context.existingObject(with: entity.objectID) as? TransactionEntity
            guard let saved = savedEntity else { throw RepositoryError.entityNotFound }
            
            return try self.convertToTransaction(saved, in: context)
        }
    }
    
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction {
        return try await performBackgroundTask { [weak self] context in
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
            
            return try self.convertToTransaction(entity, in: context)
        }
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
            
            // Reverse balances before deletion
            try self.updateAccountBalances(for: entity, isReversal: true, in: context)
            
            context.delete(entity)
            try context.save()
        }
    }
    
    func getTransaction(by id: UUID) async throws -> Transaction? {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        request.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount"]
        
        guard let entity = try context.fetch(request).first else {
            return nil
        }
        
        return try convertToTransaction(entity, in: context)
    }
    
    func getAllTransactions() async throws -> [Transaction] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionEntity.transactionDate, ascending: false)]
        request.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount"]
        request.fetchBatchSize = 50
        
        let entities = try context.fetch(request)
        return try entities.compactMap { try convertToTransaction($0, in: context) }
    }
    
    func getTransactions(for account: Account?,
                        in dateRange: ClosedRange<Date>?,
                        category: Category?) async throws -> [Transaction] {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        var predicates: [NSPredicate] = []
        
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
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionEntity.transactionDate, ascending: false)]
        request.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount"]
        
        let entities = try context.fetch(request)
        return try entities.compactMap { try convertToTransaction($0, in: context) }
    }
    
    // MARK: - Pending Transaction Operations
    
    func createPendingTransaction(_ pending: PendingTransaction) async throws -> PendingTransaction {
        return try await performBackgroundTask { context in
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
            }
            
            // Set suggested category
            if let suggestedCategory = pending.suggestedCategory {
                entity.suggestedCategoryId = suggestedCategory.id
            }
            
            try context.save()
            return pending
        }
    }
    
    func getPendingTransactions(for account: Account?) async throws -> [PendingTransaction] {
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
        request.relationshipKeyPathsForPrefetching = ["account"]
        
        let entities = try context.fetch(request)
        return try await withThrowingTaskGroup(of: PendingTransaction?.self) { group in
            for entity in entities {
                group.addTask {
                    return try await self.convertToPendingTransaction(entity)
                }
            }
            
            var results: [PendingTransaction] = []
            for try await pending in group {
                if let pending = pending {
                    results.append(pending)
                }
            }
            return results
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
    }
    
    // MARK: - Account Operations
    
    func createAccount(_ account: Account) async throws -> Account {
        return try await performBackgroundTask { context in
            let entity = AccountEntity(context: context)
            entity.id = account.id
            entity.name = account.name
            entity.tag = account.tag
            entity.balance = NSDecimalNumber(decimal: account.balance)
            entity.isDefault = account.isDefault
            entity.createdAt = Date()
            
            // If this is set as default, unset other defaults
            if account.isDefault {
                let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isDefault == true")
                let existingDefaults = try context.fetch(request)
                existingDefaults.forEach { $0.isDefault = false }
            }
            
            try context.save()
            return account
        }
    }
    
    func updateAccount(_ account: Account) async throws -> Account {
        return try await performBackgroundTask { context in
            let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", account.id as CVarArg)
            request.fetchLimit = 1
            
            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.entityNotFound
            }
            
            entity.name = account.name
            entity.tag = account.tag
            entity.balance = NSDecimalNumber(decimal: account.balance)
            
            if account.isDefault && !entity.isDefault {
                // Unset other defaults
                let defaultRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
                defaultRequest.predicate = NSPredicate(format: "isDefault == true")
                let existingDefaults = try context.fetch(defaultRequest)
                existingDefaults.forEach { $0.isDefault = false }
                entity.isDefault = true
            }
            
            try context.save()
            return account
        }
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
                throw RepositoryError.conflictDetected("Рахунок має транзакції")
            }
            
            context.delete(entity)
            try context.save()
        }
    }
    
    func getAllAccounts() async throws -> [Account] {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AccountEntity.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \AccountEntity.name, ascending: true)
        ]
        
        let entities = try context.fetch(request)
        return entities.map { entity in
            Account(
                id: entity.id ?? UUID(),
                name: entity.name ?? "",
                tag: entity.tag ?? "",
                balance: entity.balance?.decimalValue ?? 0,
                isDefault: entity.isDefault
            )
        }
    }
    
    func getDefaultAccount() async throws -> Account? {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == true")
        request.fetchLimit = 1
        
        guard let entity = try context.fetch(request).first else {
            return nil
        }
        
        return Account(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            tag: entity.tag ?? "",
            balance: entity.balance?.decimalValue ?? 0,
            isDefault: entity.isDefault
        )
    }
    
    // MARK: - Category Operations
    
    func createCategory(_ category: Category) async throws -> Category {
        return try await performBackgroundTask { context in
            let entity = CategoryEntity(context: context)
            entity.id = category.id
            entity.name = category.name
            entity.icon = category.icon
            entity.colorHex = category.colorHex
            entity.isSystem = false
            entity.sortOrder = Int32(try context.count(for: CategoryEntity.fetchRequest()))
            
            try context.save()
            return category
        }
    }
    
    func updateCategory(_ category: Category) async throws -> Category {
        return try await performBackgroundTask { context in
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
            return category
        }
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
                throw RepositoryError.conflictDetected("Категорія має транзакції")
            }
            
            context.delete(entity)
            try context.save()
        }
    }
    
    func getAllCategories() async throws -> [Category] {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CategoryEntity.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CategoryEntity.name, ascending: true)
        ]
        
        let entities = try context.fetch(request)
        return entities.map { entity in
            Category(
                id: entity.id ?? UUID(),
                name: entity.name ?? "",
                icon: entity.icon ?? "circle",
                colorHex: entity.colorHex ?? "#000000"
            )
        }
    }
    
    // MARK: - Batch Operations
    
    func performBatch(_ operation: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await performBackgroundTask { context in
            try operation(context)
            try context.save()
        }
    }
    
    // MARK: - Private Helpers
    
    private func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = backgroundContext
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
    
    private func fetchAccountEntity(by id: UUID, in context: NSManagedObjectContext) throws -> AccountEntity? {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    private func fetchCategoryEntity(by id: UUID, in context: NSManagedObjectContext) throws -> CategoryEntity? {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    private func updateEntity(_ entity: TransactionEntity,
                             from transaction: Transaction,
                             in context: NSManagedObjectContext) throws {
        entity.id = transaction.id
        entity.timestamp = transaction.timestamp
        entity.transactionDate = transaction.transactionDate
        entity.type = transaction.type.rawValue
        entity.amount = NSDecimalNumber(decimal: transaction.amount)
        entity.descriptionText = transaction.description
        
        // Set relationships
        if let category = transaction.category {
            entity.category = try fetchCategoryEntity(by: category.id, in: context)
        }
        
        if let fromAccount = transaction.fromAccount {
            entity.fromAccount = try fetchAccountEntity(by: fromAccount.id, in: context)
        }
        
        if let toAccount = transaction.toAccount {
            entity.toAccount = try fetchAccountEntity(by: toAccount.id, in: context)
        }
    }
    
    private func updateAccountBalances(for transaction: TransactionEntity,
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
    
    private func convertToTransaction(_ entity: TransactionEntity,
                                     in context: NSManagedObjectContext) throws -> Transaction {
        guard let id = entity.id,
              let type = entity.type,
              let transactionType = TransactionType(rawValue: type),
              let amount = entity.amount?.decimalValue,
              let description = entity.descriptionText else {
            throw RepositoryError.invalidData("Невірні дані транзакції")
        }
        
        var category: Category? = nil
        if let categoryEntity = entity.category {
            category = Category(
                id: categoryEntity.id ?? UUID(),
                name: categoryEntity.name ?? "",
                icon: categoryEntity.icon ?? "circle",
                colorHex: categoryEntity.colorHex ?? "#000000"
            )
        }
        
        var fromAccount: Account? = nil
        if let accountEntity = entity.fromAccount {
            fromAccount = Account(
                id: accountEntity.id ?? UUID(),
                name: accountEntity.name ?? "",
                tag: accountEntity.tag ?? "",
                balance: accountEntity.balance?.decimalValue ?? 0,
                isDefault: accountEntity.isDefault
            )
        }
        
        var toAccount: Account? = nil
        if let accountEntity = entity.toAccount {
            toAccount = Account(
                id: accountEntity.id ?? UUID(),
                name: accountEntity.name ?? "",
                tag: accountEntity.tag ?? "",
                balance: accountEntity.balance?.decimalValue ?? 0,
                isDefault: accountEntity.isDefault
            )
        }
        
        return Transaction(
            id: id,
            timestamp: entity.timestamp ?? Date(),
            transactionDate: entity.transactionDate ?? Date(),
            type: transactionType,
            amount: amount,
            category: category,
            description: description,
            fromAccount: fromAccount,
            toAccount: toAccount
        )
    }
    
    private func convertToPendingTransaction(_ entity: PendingTransactionEntity) async throws -> PendingTransaction? {
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
        
        let account = Account(
            id: accountEntity.id ?? UUID(),
            name: accountEntity.name ?? "",
            tag: accountEntity.tag ?? "",
            balance: accountEntity.balance?.decimalValue ?? 0,
            isDefault: accountEntity.isDefault
        )
        
        var suggestedCategory: Category? = nil
        if let suggestedId = entity.suggestedCategoryId {
            suggestedCategory = try await getCategoryById(suggestedId)
        }
        
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
    
    private func getCategoryById(_ id: UUID) async throws -> Category? {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        guard let entity = try context.fetch(request).first else {
            return nil
        }
        
        return Category(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            icon: entity.icon ?? "circle",
            colorHex: entity.colorHex ?? "#000000"
        )
    }
}

