//
//  TransactionViewModel.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI
import Combine

@MainActor
class TransactionViewModel: ObservableObject {
    private let dataManager: DataManager
    
    // Quick entry props
    @Published var entryAmount: String = ""
    @Published var entryDescription: String = ""
    @Published var selectedCategory: Category?
    @Published var selectedDate: Date = Date()
    @Published var selectedAccount: Account?
    @Published var transactionType: TransactionType = .expense
    
    @Published var isProcessing = false
    @Published var lastError: Error?
    
    var transactions: [Transaction] {
        dataManager.transactions
    }
    
    var categories: [Category] {
        dataManager.categories
    }
    
    var accounts: [Account] {
        dataManager.accounts
    }
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
        self.selectedAccount = dataManager.accounts.first { $0.isDefault } ?? dataManager.accounts.first
    }
    
    var amountDecimal: Decimal? {
        guard !entryAmount.isEmpty else { return nil }
        return Decimal(string: entryAmount.replacingOccurrences(of: ",", with: "."))
    }
    
    var isValidEntry: Bool {
        amountDecimal != nil && !entryDescription.isEmpty
    }
    
    func addTransaction() {
        guard let amount = amountDecimal,
              let account = selectedAccount else { return }
        
        isProcessing = true
        lastError = nil
        
        let transaction = Transaction(
            transactionDate: selectedDate,
            type: transactionType,
            amount: amount,
            category: selectedCategory,
            description: entryDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            fromAccount: transactionType == .expense || transactionType == .transferOut ? account : nil,
            toAccount: transactionType == .income || transactionType == .transferIn ? account : nil
        )
        
        do {
            try dataManager.addTransaction(transaction)
            clearEntry()
            
            // Sync to Google Sheets if configured
            //                Task {
            //                    await syncToGoogleSheets(transaction)
            //                }
        } catch {
            lastError = error
            print("Failed to add transaction: \(error)")
        }
        
        isProcessing = false
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        do {
            try dataManager.deleteTransaction(transaction)
        } catch {
            lastError = error
            print("Failed to delete transaction: \(error)")
        }
    }
    
    func clearEntry() {
        entryAmount = ""
        entryDescription = ""
        selectedCategory = nil
        selectedDate = Date()
        // Keep selected account and transaction type for convenience
    }
    
    func suggestCategory(for description: String) -> Category? {
        let lowercased = description.lowercased()
        
        // Smart patterns based on actual usage
        let patterns: [String: String] = [
            "нетфлікс": "підписки",
            "netflix": "підписки",
            "spotify": "підписки",
            "photoshop": "підписки",
            "chatgpt": "підписки",
            "apple": "підписки",
            "setapp": "підписки",
            "сільпо": "продукти",
            "фора": "продукти",
            "метро": "продукти",
            "atb": "продукти",
            "магаз": "продукти",
            "таксі": "таксі",
            "uber": "таксі",
            "bolt": "таксі",
            "uklon": "таксі",
            "аптека": "аптека",
            "ліки": "аптека",
            "pharmacy": "аптека"
        ]
        
        for (pattern, categoryName) in patterns {
            if lowercased.contains(pattern) {
                return categories.first { $0.name == categoryName }
            }
        }
        
        return nil
    }
    
}
