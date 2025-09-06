//
//  TransactionRepositoryProtocol.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 01.09.2025.
//

import Foundation
import CoreData
import Combine

protocol TransactionRepositoryProtocol: AnyObject {
    // Transaction Operations
    func createTransaction(_ transaction: Transaction) async throws -> Transaction
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction
    func deleteTransaction(_ transaction: Transaction) async throws
    func getTransaction(by id: UUID) async throws -> Transaction?
    func getAllTransactions() async throws -> [Transaction]
    func getTransactions(for account: Account?,
                        in dateRange: ClosedRange<Date>?,
                        category: Category?) async throws -> [Transaction]
    
    // Pending Transaction Operations (Banking Queue)
    func createPendingTransaction(_ pending: PendingTransaction) async throws -> PendingTransaction
    func getPendingTransactions(for account: Account?) async throws -> [PendingTransaction]
    func processPendingTransaction(_ pendingId: UUID,
                                  as transaction: Transaction) async throws
    func dismissPendingTransaction(_ pendingId: UUID) async throws
    
    // Account Operations
    func createAccount(_ account: Account) async throws -> Account
    func updateAccount(_ account: Account) async throws -> Account
    func deleteAccount(_ account: Account) async throws
    func getAllAccounts() async throws -> [Account]
    func getDefaultAccount() async throws -> Account?
    
    // Category Operations
    func createCategory(_ category: Category) async throws -> Category
    func updateCategory(_ category: Category) async throws -> Category
    func deleteCategory(_ category: Category) async throws
    func getAllCategories() async throws -> [Category]
    
    // Batch Operations
    func performBatch(_ operation: @escaping (NSManagedObjectContext) throws -> Void) async throws
    
    // Observers
    var transactionsPublisher: AnyPublisher<[Transaction], Never> { get }
    var accountsPublisher: AnyPublisher<[Account], Never> { get }
    var categoriesPublisher: AnyPublisher<[Category], Never> { get }
}


