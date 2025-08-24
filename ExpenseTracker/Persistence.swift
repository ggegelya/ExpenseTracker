//
//  Persistence.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 14.08.2025.
//

import CoreData
import CloudKit

enum PersistenceError: Error {
    case migrationFailed(String)
    case saveConflict
    case invalidContext
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .saveConflict:
            return "Save conflict ocurred. Please retry."
        case .invalidContext:
            return "Invalid data context"
        }
    }
}



struct PersistenceController {
    static let shared = PersistenceController()
    
    
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample category
        let foodCategory = CategoryEntity(context: viewContext)
        foodCategory.id = UUID()
        foodCategory.name = "продукти"
        foodCategory.icon = "cart.fill"
        foodCategory.colorHex = "#4CAF50"
        foodCategory.isSystem = true
        foodCategory.sortOrder = 1
        
        // Create sample account
        let mainAccount = AccountEntity(context: viewContext)
        mainAccount.id = UUID()
        mainAccount.name = "Основна картка"
        mainAccount.tag = "#main"
        mainAccount.balance = NSDecimalNumber(decimal: 5000)
        mainAccount.isDefault = true
        mainAccount.createdAt = Date()
        
        // Create sample transaction with RELATIONSHIPS
        let transaction = TransactionEntity(context: viewContext)
        transaction.id = UUID()
        transaction.timestamp = Date()
        transaction.transactionDate = Date()
        transaction.type = TransactionType.expense.rawValue
        transaction.amount = NSDecimalNumber(decimal: 250.50)
        transaction.descriptionText = "Покупки у Сільпо"
        transaction.category = foodCategory  // Relationship, not string!
        transaction.fromAccount = mainAccount  // Relationship, not UUID!
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
#if DEBUG
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
#else
            print("Unresolved error \(nsError), \(nsError.localizedDescription)")
#endif
        }
        return result
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ExpenseTracker")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.persistentStoreDescriptions.forEach { storeDescription in
            // enable History tracking in CloudKit
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Configure for performance
            storeDescription.shouldInferMappingModelAutomatically = true
            storeDescription.shouldMigrateStoreAutomatically = true
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                // In production, handle this gracefully
#if DEBUG
                fatalError("Core Data failed to load: \(error)")
#else
                // Log to analytics service
                print("Core Data error: \(error)")
                // Show user-friendly error and offer recovery options
#endif
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configure for performance
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}


