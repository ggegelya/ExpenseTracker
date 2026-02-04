//
//  TestHelpers.swift
//  ExpenseTracker
//
//  Test helper utilities for creating test infrastructure and validation
//

import Foundation
import CoreData
@preconcurrency import Combine

// MARK: - Core Data Test Helpers

/// Creates an in-memory Core Data stack for testing
/// - Parameter modelName: The name of the Core Data model (defaults to "ExpenseTracker")
/// - Returns: A configured NSPersistentContainer with in-memory store
/// - Throws: Error if the persistent container cannot be loaded
func createTestPersistentContainer(modelName: String = "ExpenseTracker") async throws -> NSPersistentContainer {
    let container = NSPersistentContainer(name: modelName)

    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    description.shouldAddStoreAsynchronously = false

    container.persistentStoreDescriptions = [description]

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        container.loadPersistentStores { _, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

    return container
}

/// Creates a test PersistenceController with in-memory store
/// - Returns: PersistenceController configured for testing
@MainActor
func createTestPersistenceController() -> PersistenceController {
    return PersistenceController(inMemory: true)
}

// MARK: - Date Generation Helpers

/// Provides convenient date generation methods for testing
enum DateGenerator {
    /// Returns the current date and time
    static func now() -> Date {
        Date()
    }

    /// Returns today at midnight
    static func today() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Returns yesterday at midnight
    static func yesterday() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: today())!
    }

    /// Returns tomorrow at midnight
    static func tomorrow() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: today())!
    }

    /// Returns a date N days ago from today
    /// - Parameter days: Number of days to subtract
    /// - Returns: Date N days ago
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: today())!
    }

    /// Returns a date N days from now
    /// - Parameter days: Number of days to add
    /// - Returns: Date N days in the future
    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: today())!
    }

    /// Returns the first day of the current month
    static func startOfMonth() -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: components)!
    }

    /// Returns the last day of the current month
    static func endOfMonth() -> Date {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth())!
        return Calendar.current.date(byAdding: .day, value: -1, to: nextMonth)!
    }

    /// Returns the first day of last month
    static func startOfLastMonth() -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: startOfMonth())!
    }

    /// Returns the last day of last month
    static func endOfLastMonth() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: startOfMonth())!
    }

    /// Returns the first day of next month
    static func startOfNextMonth() -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth())!
    }

    /// Returns the first day of the current year
    static func startOfYear() -> Date {
        let components = Calendar.current.dateComponents([.year], from: Date())
        return Calendar.current.date(from: components)!
    }

    /// Returns a specific date
    /// - Parameters:
    ///   - year: Year component
    ///   - month: Month component (1-12)
    ///   - day: Day component (1-31)
    ///   - hour: Hour component (0-23), defaults to 0
    ///   - minute: Minute component (0-59), defaults to 0
    /// - Returns: The specified date
    static func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    /// Returns a random date within the last N days
    /// - Parameter days: Number of days to look back
    /// - Returns: A random date in the range
    static func randomDate(withinLast days: Int) -> Date {
        let randomDays = Int.random(in: 0...days)
        return daysAgo(randomDays)
    }
}

// MARK: - Decimal Comparison Helpers

/// Provides decimal comparison utilities for currency testing
enum DecimalComparison {
    /// Checks if two decimal values are equal within a tolerance
    /// - Parameters:
    ///   - actual: The actual value
    ///   - expected: The expected value
    ///   - tolerance: The acceptable difference (defaults to 0.01 for currency)
    /// - Returns: True if values are equal within tolerance
    static func areEqual(
        _ actual: Decimal,
        _ expected: Decimal,
        tolerance: Decimal = 0.01
    ) -> Bool {
        let difference = abs(actual - expected)
        return difference <= tolerance
    }

    /// Checks if a decimal value is positive
    static func isPositive(_ value: Decimal) -> Bool {
        return value > 0
    }

    /// Checks if a decimal value is negative
    static func isNegative(_ value: Decimal) -> Bool {
        return value < 0
    }

    /// Checks if a decimal value is zero or positive
    static func isNonNegative(_ value: Decimal) -> Bool {
        return value >= 0
    }

    /// Checks if a decimal value is within a specific range
    static func isInRange(
        _ value: Decimal,
        min: Decimal,
        max: Decimal
    ) -> Bool {
        return value >= min && value <= max
    }

    /// Returns the absolute difference between two decimals
    static func difference(
        _ value1: Decimal,
        _ value2: Decimal
    ) -> Decimal {
        return abs(value1 - value2)
    }
}

// MARK: - Async Test Utilities

/// Provides utilities for testing asynchronous code
enum AsyncTestUtilities {
    /// Waits for a publisher to emit a value or complete
    /// - Parameters:
    ///   - publisher: The publisher to wait for
    ///   - timeout: Maximum time to wait in seconds (defaults to 5)
    /// - Returns: The first value emitted by the publisher
    /// - Throws: Error if timeout is reached or publisher fails
    static func awaitPublisher<P: Publisher>(
        _ publisher: P,
        timeout: TimeInterval = 5
    ) async throws -> P.Output where P.Output: Sendable {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var timedOut = false

            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                timedOut = true
                cancellable?.cancel()
                continuation.resume(throwing: AsyncTestError.timeout)
            }

            cancellable = publisher
                .sink(
                    receiveCompletion: { completion in
                        timer.invalidate()
                        if !timedOut {
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        }
                    },
                    receiveValue: { value in
                        timer.invalidate()
                        if !timedOut {
                            continuation.resume(returning: value)
                        }
                    }
                )
        }
    }

    /// Collects all values from a publisher until completion
    /// - Parameters:
    ///   - publisher: The publisher to collect from
    ///   - timeout: Maximum time to wait in seconds (defaults to 5)
    /// - Returns: Array of all emitted values
    /// - Throws: Error if timeout is reached or publisher fails
    static func collectPublisher<P: Publisher>(
        _ publisher: P,
        timeout: TimeInterval = 5
    ) async throws -> [P.Output] where P.Output: Sendable {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var timedOut = false

            let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                timedOut = true
                cancellable?.cancel()
                continuation.resume(throwing: AsyncTestError.timeout)
            }

            cancellable = publisher
                .collect()
                .sink(
                    receiveCompletion: { completion in
                        timer.invalidate()
                        if !timedOut {
                            if case .failure(let error) = completion {
                                continuation.resume(throwing: error)
                            }
                        }
                    },
                    receiveValue: { collectedValues in
                        timer.invalidate()
                        if !timedOut {
                            continuation.resume(returning: collectedValues)
                        }
                    }
                )
        }
    }

    /// Waits for a specific amount of time
    /// - Parameter seconds: Number of seconds to wait
    static func wait(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Waits for a condition to become true
    /// - Parameters:
    ///   - timeout: Maximum time to wait in seconds (defaults to 5)
    ///   - pollingInterval: How often to check the condition in seconds (defaults to 0.1)
    ///   - condition: The condition to check
    /// - Throws: Error if timeout is reached
    static func waitUntil(
        timeout: TimeInterval = 5,
        pollingInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) async throws {
        let startTime = Date()

        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw AsyncTestError.timeout
            }
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }

    /// Executes a block on the main actor and returns the result
    /// - Parameter block: The block to execute
    /// - Returns: The result of the block
    static func onMainActor<T: Sendable>(_ block: @MainActor @Sendable () -> T) async -> T {
        await MainActor.run(body: block)
    }
}

// MARK: - Async Test Errors

enum AsyncTestError: Error, LocalizedError {
    case timeout
    case unexpectedValue
    case conditionNotMet

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .unexpectedValue:
            return "Received unexpected value"
        case .conditionNotMet:
            return "Expected condition was not met"
        }
    }
}

// MARK: - Random Data Helpers

/// Provides utilities for generating random test data
enum RandomDataGenerator {
    /// Generates a random decimal amount within a range
    /// - Parameters:
    ///   - min: Minimum value (defaults to 1)
    ///   - max: Maximum value (defaults to 1000)
    /// - Returns: Random decimal amount
    static func randomAmount(min: Decimal = 1, max: Decimal = 1000) -> Decimal {
        let range = NSDecimalNumber(decimal: max - min).doubleValue
        let randomValue = Double.random(in: 0...range)
        return min + Decimal(randomValue)
    }

    /// Generates a random merchant name
    static func randomMerchantName() -> String {
        let merchants = [
            "Silpo",
            "ATB",
            "Uber",
            "Netflix",
            "Spotify",
            "Amazon",
            "McDonald's",
            "KFC",
            "Аптека",
            "Rozetka"
        ]
        return merchants.randomElement()!
    }

    /// Generates a random transaction description
    static func randomDescription() -> String {
        let descriptions = [
            "Продукти",
            "Таксі",
            "Кафе",
            "Аптека",
            "Транспорт",
            "Одяг",
            "Розваги",
            "Комунальні послуги",
            "Зарплата",
            "Фріланс"
        ]
        return descriptions.randomElement()!
    }
}
