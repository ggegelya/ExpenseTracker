//
//  RepositoryError.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import CoreData
import Combine

enum RepositoryError: LocalizedError {
    case contextUnavailable
    case entityNotFound
    case invalidData(String)
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case migrationRequired
    case conflictDetected(String)
    
    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return String(localized: "error.repo.contextUnavailable")
        case .entityNotFound:
            return String(localized: "error.repo.entityNotFound")
        case .invalidData(let details):
            return "\(String(localized: "error.repo.invalidData")): \(details)"
        case .saveFailed(let error):
            return "\(String(localized: "error.repo.saveFailed")): \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "\(String(localized: "error.repo.fetchFailed")): \(error.localizedDescription)"
        case .migrationRequired:
            return String(localized: "error.repo.migrationRequired")
        case .conflictDetected(let details):
            return "\(String(localized: "error.repo.conflictDetected")): \(details)"
        }
    }
}
