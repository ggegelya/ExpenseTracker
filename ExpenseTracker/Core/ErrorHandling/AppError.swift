//
//  AppError.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 07.09.2025.
//

import Foundation

enum AppError: LocalizedError, Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAmount, .invalidAmount),
             (.insufficientFunds, .insufficientFunds),
             (.networkUnavailable, .networkUnavailable),
             (.bankingServiceUnavailable, .bankingServiceUnavailable),
             (.categoryRequired, .categoryRequired),
             (.accountRequired, .accountRequired),
             (.dataCorruption, .dataCorruption),
             (.syncFailed, .syncFailed),
             (.authenticationFailed, .authenticationFailed),
             (.permissionDenied, .permissionDenied),
             (.bankTokenExpired, .bankTokenExpired),
             (.bankAccountNotFound, .bankAccountNotFound),
             (.bankTransactionFailed, .bankTransactionFailed),
             (.dailyLimitExceeded, .dailyLimitExceeded):
            return true
        case (.repositoryError(let lhsError), .repositoryError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    // User facing errors
    case invalidAmount
    case insufficientFunds
    case networkUnavailable
    case bankingServiceUnavailable
    case categoryRequired
    case accountRequired
    
    // System errors
    case dataCorruption
    case syncFailed
    case authenticationFailed
    case permissionDenied
    
    // Banking specific errors
    case bankTokenExpired
    case bankAccountNotFound
    case bankTransactionFailed
    case dailyLimitExceeded
    
    // Repository errors
    case repositoryError(RepositoryError)
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return String(localized: "error.invalidAmount")
        case .insufficientFunds:
            return String(localized: "error.insufficientFunds")
        case .networkUnavailable:
            return String(localized: "error.networkUnavailable")
        case .bankingServiceUnavailable:
            return String(localized: "error.bankingServiceUnavailable")
        case .categoryRequired:
            return String(localized: "error.categoryRequired")
        case .accountRequired:
            return String(localized: "error.accountRequired")
        case .dataCorruption:
            return String(localized: "error.dataCorruption")
        case .syncFailed:
            return String(localized: "error.syncFailed")
        case .authenticationFailed:
            return String(localized: "error.authenticationFailed")
        case .permissionDenied:
            return String(localized: "error.permissionDenied")
        case .bankTokenExpired:
            return String(localized: "error.bankTokenExpired")
        case .bankAccountNotFound:
            return String(localized: "error.bankAccountNotFound")
        case .bankTransactionFailed:
            return String(localized: "error.bankTransactionFailed")
        case .dailyLimitExceeded:
            return String(localized: "error.dailyLimitExceeded")
        case .repositoryError(let repoError):
            return repoError.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "error.recovery.networkUnavailable")
        case .bankingServiceUnavailable:
            return String(localized: "error.recovery.bankingServiceUnavailable")
        case .bankTokenExpired:
            return String(localized: "error.recovery.bankTokenExpired")
        case .dataCorruption:
            return String(localized: "error.recovery.dataCorruption")
        case .dailyLimitExceeded:
            return String(localized: "error.recovery.dailyLimitExceeded")
        default:
            return nil
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .bankingServiceUnavailable, .syncFailed:
            return true
        case .bankTokenExpired, .authenticationFailed, .dataCorruption:
            return false
        default:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .dataCorruption, .authenticationFailed:
            return .critical
        case .bankTokenExpired, .syncFailed:
            return .high
        case .networkUnavailable, .bankingServiceUnavailable:
            return .medium
        default:
            return .low
        }
    }
}

// MARK: - Error Mapping Extensions
extension AppError {
    init(from repositoryError: RepositoryError) {
        self = .repositoryError(repositoryError)
    }
    
    init(from networkError: URLError) {
        switch networkError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            self = .networkUnavailable
        case .userAuthenticationRequired:
            self = .authenticationFailed
        default:
            self = .networkUnavailable
        }
    }
}
