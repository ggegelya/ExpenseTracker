//
//  Environment.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 01.09.2025.
//

enum AppEnvironment {
    case production, staging, testing, preview
    
    var usesInMemoryStore: Bool {
        switch self {
        case .testing, .preview:
            return true
        case .production, .staging:
            return false
        }
    }
    
    
}
