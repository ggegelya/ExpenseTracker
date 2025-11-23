//
//  MockAnalyticsService.swift
//  ExpenseTracker
//
//  Mock implementation of AnalyticsServiceProtocol for testing
//

import Foundation

/// Mock implementation of AnalyticsServiceProtocol for testing
/// Tracks all analytics events and errors for verification
final class MockAnalyticsService: AnalyticsServiceProtocol {

    // MARK: - Tracked Data

    struct EventRecord {
        let event: AnalyticsEvent
        let timestamp: Date
    }

    struct ErrorRecord {
        let error: Error
        let context: String?
        let timestamp: Date
    }

    private(set) var eventRecords: [EventRecord] = []
    private(set) var errorRecords: [ErrorRecord] = []

    // MARK: - Configuration

    /// Whether to print tracked events to console (useful for debugging tests)
    var printEvents: Bool = false

    /// Whether to print tracked errors to console (useful for debugging tests)
    var printErrors: Bool = false

    // MARK: - Initialization

    init() {}

    // MARK: - AnalyticsServiceProtocol Implementation

    func trackEvent(_ event: AnalyticsEvent) {
        let record = EventRecord(event: event, timestamp: Date())
        eventRecords.append(record)

        if printEvents {
            print("[MockAnalytics] Event: \(event)")
        }
    }

    func trackError(_ error: Error, context: String?) {
        let record = ErrorRecord(error: error, context: context, timestamp: Date())
        errorRecords.append(record)

        if printErrors {
            print("[MockAnalytics] Error: \(error) - Context: \(context ?? "none")")
        }
    }

    // MARK: - Test Verification Methods

    /// Returns all tracked events
    var events: [AnalyticsEvent] {
        eventRecords.map { $0.event }
    }

    /// Returns all tracked errors
    var errors: [Error] {
        errorRecords.map { $0.error }
    }

    /// Returns the number of tracked events
    var eventCount: Int {
        eventRecords.count
    }

    /// Returns the number of tracked errors
    var errorCount: Int {
        errorRecords.count
    }

    /// Returns whether any events were tracked
    var hasTrackedEvents: Bool {
        !eventRecords.isEmpty
    }

    /// Returns whether any errors were tracked
    var hasTrackedErrors: Bool {
        !errorRecords.isEmpty
    }

    /// Clears all tracked events and errors
    func reset() {
        eventRecords.removeAll()
        errorRecords.removeAll()
    }

    /// Clears only tracked events
    func clearEvents() {
        eventRecords.removeAll()
    }

    /// Clears only tracked errors
    func clearErrors() {
        errorRecords.removeAll()
    }

    // MARK: - Event-Specific Verification

    /// Returns whether a specific event type was tracked
    func wasEventTracked(_ eventType: AnalyticsEventType) -> Bool {
        eventRecords.contains { $0.event.type == eventType }
    }

    /// Returns the number of times a specific event type was tracked
    func eventCount(for eventType: AnalyticsEventType) -> Int {
        eventRecords.filter { $0.event.type == eventType }.count
    }

    /// Returns all records of a specific event type
    func records(for eventType: AnalyticsEventType) -> [EventRecord] {
        eventRecords.filter { $0.event.type == eventType }
    }

    /// Returns the first tracked event of a specific type
    func firstEvent(ofType eventType: AnalyticsEventType) -> AnalyticsEvent? {
        eventRecords.first { $0.event.type == eventType }?.event
    }

    /// Returns the last tracked event of a specific type
    func lastEvent(ofType eventType: AnalyticsEventType) -> AnalyticsEvent? {
        eventRecords.last { $0.event.type == eventType }?.event
    }

    /// Returns the most recent event
    var lastEvent: AnalyticsEvent? {
        eventRecords.last?.event
    }

    // MARK: - Transaction Event Verification

    /// Returns whether a transaction addition was tracked
    func wasTransactionAdded() -> Bool {
        wasEventTracked(.transactionAdded)
    }

    /// Returns all transaction addition events
    func transactionAddedEvents() -> [AnalyticsEvent] {
        eventRecords
            .filter { $0.event.type == .transactionAdded }
            .map { $0.event }
    }

    /// Returns whether a transaction with a specific amount was tracked
    func wasTransactionAdded(amount: Decimal) -> Bool {
        eventRecords.contains { record in
            if case .transactionAdded(let trackedAmount, _) = record.event {
                return trackedAmount == amount
            }
            return false
        }
    }

    /// Returns whether a transaction in a specific category was tracked
    func wasTransactionAdded(category: String) -> Bool {
        eventRecords.contains { record in
            if case .transactionAdded(_, let trackedCategory) = record.event {
                return trackedCategory == category
            }
            return false
        }
    }

    /// Returns whether a transaction deletion was tracked
    func wasTransactionDeleted() -> Bool {
        wasEventTracked(.transactionDeleted)
    }

    // MARK: - Account Event Verification

    /// Returns whether an account connection was tracked
    func wasAccountConnected() -> Bool {
        wasEventTracked(.accountConnected)
    }

    /// Returns whether an account connection for a specific bank was tracked
    func wasAccountConnected(bankName: String) -> Bool {
        eventRecords.contains { record in
            if case .accountConnected(let trackedBankName) = record.event {
                return trackedBankName == bankName
            }
            return false
        }
    }

    /// Returns all account connection events
    func accountConnectionEvents() -> [AnalyticsEvent] {
        eventRecords
            .filter { $0.event.type == .accountConnected }
            .map { $0.event }
    }

    // MARK: - Category Event Verification

    /// Returns whether a category creation was tracked
    func wasCategoryCreated() -> Bool {
        wasEventTracked(.categoryCreated)
    }

    /// Returns the number of category creation events
    func categoryCreationCount() -> Int {
        eventCount(for: .categoryCreated)
    }

    // MARK: - Export Event Verification

    /// Returns whether an export completion was tracked
    func wasExportCompleted() -> Bool {
        wasEventTracked(.exportCompleted)
    }

    /// Returns whether an export in a specific format was tracked
    func wasExportCompleted(format: String) -> Bool {
        eventRecords.contains { record in
            if case .exportCompleted(let trackedFormat) = record.event {
                return trackedFormat == format
            }
            return false
        }
    }

    /// Returns all export completion events
    func exportCompletionEvents() -> [AnalyticsEvent] {
        eventRecords
            .filter { $0.event.type == .exportCompleted }
            .map { $0.event }
    }

    // MARK: - Error Verification

    /// Returns whether an error was tracked with a specific context
    func wasErrorTracked(withContext context: String) -> Bool {
        errorRecords.contains { $0.context == context }
    }

    /// Returns all errors tracked with a specific context
    func errors(withContext context: String) -> [Error] {
        errorRecords
            .filter { $0.context == context }
            .map { $0.error }
    }

    /// Returns the most recent tracked error
    var lastError: Error? {
        errorRecords.last?.error
    }

    /// Returns the context of the most recent error
    var lastErrorContext: String? {
        errorRecords.last?.context
    }

    /// Returns all error contexts
    var errorContexts: [String?] {
        errorRecords.map { $0.context }
    }

    // MARK: - Time-Based Verification

    /// Returns events tracked within a specific time interval
    func events(since date: Date) -> [EventRecord] {
        eventRecords.filter { $0.timestamp >= date }
    }

    /// Returns errors tracked within a specific time interval
    func errors(since date: Date) -> [ErrorRecord] {
        errorRecords.filter { $0.timestamp >= date }
    }

    /// Returns the timestamp of the first event
    var firstEventTimestamp: Date? {
        eventRecords.first?.timestamp
    }

    /// Returns the timestamp of the last event
    var lastEventTimestamp: Date? {
        eventRecords.last?.timestamp
    }
}

// MARK: - AnalyticsEvent Extensions for Testing

extension AnalyticsEvent {
    /// Returns the type of the analytics event for easier filtering
    var type: AnalyticsEventType {
        switch self {
        case .transactionAdded:
            return .transactionAdded
        case .transactionDeleted:
            return .transactionDeleted
        case .accountConnected:
            return .accountConnected
        case .categoryCreated:
            return .categoryCreated
        case .exportCompleted:
            return .exportCompleted
        }
    }
}

/// Enum representing analytics event types for easier filtering
enum AnalyticsEventType: Equatable {
    case transactionAdded
    case transactionDeleted
    case accountConnected
    case categoryCreated
    case exportCompleted
}

// MARK: - AnalyticsEvent Equatable Conformance

extension AnalyticsEvent: Equatable {
    static func == (lhs: AnalyticsEvent, rhs: AnalyticsEvent) -> Bool {
        switch (lhs, rhs) {
        case (.transactionAdded(let lAmount, let lCategory), .transactionAdded(let rAmount, let rCategory)):
            return lAmount == rAmount && lCategory == rCategory
        case (.transactionDeleted, .transactionDeleted):
            return true
        case (.accountConnected(let lBank), .accountConnected(let rBank)):
            return lBank == rBank
        case (.categoryCreated, .categoryCreated):
            return true
        case (.exportCompleted(let lFormat), .exportCompleted(let rFormat)):
            return lFormat == rFormat
        default:
            return false
        }
    }
}
