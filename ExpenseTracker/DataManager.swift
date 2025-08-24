//
//  DataManager.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 23.08.2025.
//

import CoreData
import Combine

@MainActor
class DataManager: ObservableObject {
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    @Published var transactions: [Transaction] = []
    @Published var accounts: [Account] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var lastError: Error?
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadData()
        setupDefaultsIfNeeded()
        observeChanges()
    }
    
    // MARK: - Change Observation
    private func observeChanges() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Initial Setup
    private func setupDefaultsIfNeeded() {
        // Check if we have any accounts
        let accountRequest: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        accountRequest.fetchLimit = 1
        
        do {
            let accountCount = try context.count(for: accountRequest)
            if accountCount == 0 {
                try createDefaultAccount()
            }
            
            // Check categories
            let categoryRequest: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
            categoryRequest.fetchLimit = 1
            let categoryCount = try context.count(for: categoryRequest)
            
            if categoryCount == 0 {
                try createDefaultCategories()
            }
            
            loadData()
        } catch {
            lastError = error
            print("Setup error: \(error)")
        }
    }
    
    private func createDefaultAccount() throws {
        let defaultAccount = AccountEntity(context: context)
        defaultAccount.id = UUID()
        defaultAccount.name = "Основна картка"
        defaultAccount.tag = "#main"
        defaultAccount.balance = 0
        defaultAccount.isDefault = true
        defaultAccount.createdAt = Date()
        
        try saveContext()
    }
    
    private func createDefaultCategories() throws {
        let defaultCategories = [
            ("продукти", "cart.fill", "#4CAF50", 1),
            ("таксі", "car.fill", "#FFC107", 2),
            ("підписки", "repeat", "#9C27B0", 3),
            ("комуналка", "house.fill", "#2196F3", 4),
            ("аптека", "cross.case.fill", "#F44336", 5),
            ("інше", "ellipsis.circle.fill", "#607D8B", 6)
        ]
        
        for (name, icon, color, order) in defaultCategories {
            let category = CategoryEntity(context: context)
            category.id = UUID()
            category.name = name
            category.icon = icon
            category.colorHex = color
            category.sortOrder = Int32(order)
            category.isSystem = true
        }
        
        try saveContext()
    }
    
    // MARK: - Data Loading with Proper Relationships
    func loadData() {
        isLoading = true
        loadTransactions()
        loadAccounts()
        loadCategories()
        isLoading = false
    }
    
    private func loadTransactions() {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)]
        
        // Prefetch relationships to avoid N+1 queries
        request.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount"]
        
        // Batch loading for performance
        request.fetchBatchSize = 20
        
        do {
            let entities = try context.fetch(request)
            self.transactions = entities.compactMap { entity in
                convertToTransaction(entity)
            }
        } catch {
            lastError = error
            print("Error fetching transactions: \(error)")
        }
    }
    
    private func loadAccounts() {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AccountEntity.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \AccountEntity.name, ascending: true)
        ]
        
        do {
            let entities = try context.fetch(request)
            self.accounts = entities.map { entity in
                Account(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "",
                    tag: entity.tag ?? "",
                    balance: entity.balance?.decimalValue ?? 0,
                    isDefault: entity.isDefault
                )
            }
        } catch {
            lastError = error
            print("Error fetching accounts: \(error)")
        }
    }
    
    private func loadCategories() {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CategoryEntity.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CategoryEntity.name, ascending: true)
        ]
        
        do {
            let entities = try context.fetch(request)
            self.categories = entities.map { entity in
                Category(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "",
                    icon: entity.icon ?? "circle",
                    colorHex: entity.colorHex ?? "#000000"
                )
            }
        } catch {
            lastError = error
            print("Error fetching categories: \(error)")
        }
    }
    
    // MARK: - Transaction Operations with Relationships
    func addTransaction(_ transaction: Transaction) throws {
        let entity = TransactionEntity(context: context)
        entity.id = transaction.id
        entity.timestamp = transaction.timestamp
        entity.transactionDate = transaction.transactionDate
        entity.type = transaction.type.rawValue
        entity.amount = NSDecimalNumber(decimal: transaction.amount)
        entity.descriptionText = transaction.description
        
        // Set RELATIONSHIPS, not IDs or strings!
        if let categoryId = transaction.category?.id {
            entity.category = try fetchCategoryEntity(by: categoryId)
        }
        
        if let fromAccountId = transaction.fromAccount?.id {
            entity.fromAccount = try fetchAccountEntity(by: fromAccountId)
        }
        
        if let toAccountId = transaction.toAccount?.id {
            entity.toAccount = try fetchAccountEntity(by: toAccountId)
        }
        
        // Update account balances through relationships
        updateAccountBalances(for: entity)
        
        try saveContext()
        loadData()
    }
    
    func deleteTransaction(_ transaction: Transaction) throws {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        if let entity = entities.first {
            // Reverse balance changes through relationships
            reverseAccountBalances(for: entity)
            context.delete(entity)
            try saveContext()
            loadData()
        }
    }
    
    func updateTransaction(_ transaction: Transaction) throws {
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", transaction.id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try context.fetch(request)
        if let entity = entities.first {
            // Reverse old balance changes
            reverseAccountBalances(for: entity)
            
            // Update entity
            entity.timestamp = Date() // Update modification time
            entity.transactionDate = transaction.transactionDate
            entity.type = transaction.type.rawValue
            entity.amount = NSDecimalNumber(decimal: transaction.amount)
            entity.descriptionText = transaction.description
            
            // Update RELATIONSHIPS
            if let categoryId = transaction.category?.id {
                entity.category = try fetchCategoryEntity(by: categoryId)
            } else {
                entity.category = nil
            }
            
            if let fromAccountId = transaction.fromAccount?.id {
                entity.fromAccount = try fetchAccountEntity(by: fromAccountId)
            } else {
                entity.fromAccount = nil
            }
            
            if let toAccountId = transaction.toAccount?.id {
                entity.toAccount = try fetchAccountEntity(by: toAccountId)
            } else {
                entity.toAccount = nil
            }
            
            // Apply new balance changes
            updateAccountBalances(for: entity)
            
            try saveContext()
            loadData()
        }
    }
    
    // MARK: - Helper Methods for Fetching Related Entities
    private func fetchAccountEntity(by id: UUID) throws -> AccountEntity? {
        let request: NSFetchRequest<AccountEntity> = AccountEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    private func fetchCategoryEntity(by id: UUID) throws -> CategoryEntity? {
        let request: NSFetchRequest<CategoryEntity> = CategoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
    
    // MARK: - Account Balance Management
    private func updateAccountBalances(for transaction: TransactionEntity) {
        guard let typeString = transaction.type,
              let type = TransactionType(rawValue: typeString),
              let amount = transaction.amount?.decimalValue else { return }
        
        switch type {
        case .expense:
            if let account = transaction.fromAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance - amount)
            }
        case .income:
            if let account = transaction.toAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance + amount)
            }
        case .transferOut:
            if let account = transaction.fromAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance - amount)
            }
        case .transferIn:
            if let account = transaction.toAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance + amount)
            }
        }
    }
    
    private func reverseAccountBalances(for transaction: TransactionEntity) {
        guard let typeString = transaction.type,
              let type = TransactionType(rawValue: typeString),
              let amount = transaction.amount?.decimalValue else { return }
        
        switch type {
        case .expense:
            if let account = transaction.fromAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance + amount)
            }
        case .income:
            if let account = transaction.toAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance - amount)
            }
        case .transferOut:
            if let account = transaction.fromAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance + amount)
            }
        case .transferIn:
            if let account = transaction.toAccount {
                let currentBalance = account.balance?.decimalValue ?? 0
                account.balance = NSDecimalNumber(decimal: currentBalance - amount)
            }
        }
    }
    
    // MARK: - Data Conversion with Relationships
    private func convertToTransaction(_ entity: TransactionEntity) -> Transaction? {
        guard let id = entity.id,
              let type = entity.type,
              let transactionType = TransactionType(rawValue: type),
              let amount = entity.amount?.decimalValue,
              let description = entity.descriptionText else {
            return nil
        }
        
        // Convert relationships to model objects
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
    
    // MARK: - Save Context with Error Handling
    private func saveContext() throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
    
    // MARK: - Query Methods with Relationships
    func getTransactions(for account: Account? = nil,
                        in dateRange: ClosedRange<Date>? = nil,
                        category: Category? = nil) -> [Transaction] {
        var predicates: [NSPredicate] = []
        
        if let account = account {
            let accountPredicate = NSPredicate(
                format: "fromAccount.id == %@ OR toAccount.id == %@",
                account.id as CVarArg,
                account.id as CVarArg
            )
            predicates.append(accountPredicate)
        }
        
        if let dateRange = dateRange {
            let datePredicate = NSPredicate(
                format: "transactionDate >= %@ AND transactionDate <= %@",
                dateRange.lowerBound as NSDate,
                dateRange.upperBound as NSDate
            )
            predicates.append(datePredicate)
        }
        
        if let category = category {
            let categoryPredicate = NSPredicate(
                format: "category.id == %@",
                category.id as CVarArg
            )
            predicates.append(categoryPredicate)
        }
        
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransactionEntity.transactionDate, ascending: false)]
        request.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount"]
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { convertToTransaction($0) }
        } catch {
            print("Query error: \(error)")
            return []
        }
    }
    
    // MARK: - Statistics Methods
    func getCategoryStatistics(for period: DateComponents) -> [(Category, Decimal)] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: period, to: now) else { return [] }
        
        let request: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "transactionDate >= %@ AND type == %@",
            startDate as NSDate,
            TransactionType.expense.rawValue
        )
        request.relationshipKeyPathsForPrefetching = ["category"]
        
        do {
            let entities = try context.fetch(request)
            var categoryTotals: [UUID: Decimal] = [:]
            
            for entity in entities {
                if let category = entity.category,
                   let categoryId = category.id,
                   let amount = entity.amount?.decimalValue {
                    categoryTotals[categoryId, default: 0] += amount
                }
            }
            
            return categories.compactMap { category in
                if let total = categoryTotals[category.id], total > 0 {
                    return (category, total)
                }
                return nil
            }.sorted { $0.1 > $1.1 }
        } catch {
            print("Statistics error: \(error)")
            return []
        }
    }
}
