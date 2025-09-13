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
            return "Невірна сума транзакції"
        case .insufficientFunds:
            return "Недостатньо коштів на рахунку"
        case .networkUnavailable:
            return "Відсутнє з'єднання з інтернетом"
        case .bankingServiceUnavailable:
            return "Банківський сервіс тимчасово недоступний"
        case .categoryRequired:
            return "Оберіть категорію для транзакції"
        case .accountRequired:
            return "Оберіть рахунок для транзакції"
        case .dataCorruption:
            return "Виявлено пошкодження даних. Спробуйте перезапустити додаток"
        case .syncFailed:
            return "Не вдалося синхронізувати дані"
        case .authenticationFailed:
            return "Помилка автентифікації"
        case .permissionDenied:
            return "Відмовлено в доступі"
        case .bankTokenExpired:
            return "Термін дії токену банку закінчився. Потрібно повторно підключити рахунок"
        case .bankAccountNotFound:
            return "Банківський рахунок не знайдено"
        case .bankTransactionFailed:
            return "Не вдалося обробити банківську транзакцію"
        case .dailyLimitExceeded:
            return "Перевищено денний ліміт запитів до банку"
        case .repositoryError(let repoError):
            return repoError.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Перевірте з'єднання з інтернетом та спробуйте ще раз"
        case .bankingServiceUnavailable:
            return "Спробуйте пізніше або додайте транзакцію вручну"
        case .bankTokenExpired:
            return "Перейдіть до налаштувань рахунків та повторно підключіть банк"
        case .dataCorruption:
            return "Якщо проблема повторюється, зверніться до підтримки"
        case .dailyLimitExceeded:
            return "Спробуйте завтра або зменшіть кількість запитів"
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

