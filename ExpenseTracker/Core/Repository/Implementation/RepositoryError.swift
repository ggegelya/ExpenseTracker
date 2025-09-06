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
            return "База даних недоступна"
        case .entityNotFound:
            return "Запис не знайдено"
        case .invalidData(let details):
            return "Невірні дані: \(details)"
        case .saveFailed(let error):
            return "Помилка збереження: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Помилка завантаження: \(error.localizedDescription)"
        case .migrationRequired:
            return "Потрібна міграція даних"
        case .conflictDetected(let details):
            return "Конфлікт даних: \(details)"
        }
    }
}