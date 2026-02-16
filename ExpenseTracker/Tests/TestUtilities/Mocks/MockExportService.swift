//
//  MockExportService.swift
//  ExpenseTracker
//
//  Mock implementation of ExportServiceProtocol for testing
//

import Foundation

/// Mock implementation of ExportServiceProtocol for testing
/// Simulates CSV and Google Sheets export operations and tracks calls
final class MockExportService: ExportServiceProtocol {

    // MARK: - Call Tracking

    struct ExportToCSVCall {
        let transactions: [Transaction]
        let timestamp: Date
    }

    struct ExportToGoogleSheetsCall {
        let transactions: [Transaction]
        let timestamp: Date
    }

    private(set) var csvExportCalls: [ExportToCSVCall] = []
    private(set) var googleSheetsExportCalls: [ExportToGoogleSheetsCall] = []

    // MARK: - Configuration

    /// URL to return from CSV export (defaults to a temp file)
    var csvExportResult: URL?

    /// Whether to throw an error on CSV export
    var shouldThrowErrorOnCSV: Bool = false
    var csvErrorToThrow: Error = ExportError.exportFailed("Mock CSV export failed")

    /// Whether to throw an error on Google Sheets export
    var shouldThrowErrorOnGoogleSheets: Bool = false
    var googleSheetsErrorToThrow: Error = ExportError.googleSheetsAuthenticationFailed

    /// Delay in seconds to simulate export operation (defaults to 0)
    var exportDelay: TimeInterval = 0

    /// Whether to actually create a temporary CSV file
    var createActualCSVFile: Bool = false

    // MARK: - Initialization

    init() {
        // Default CSV export result points to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        csvExportResult = tempDir.appendingPathComponent("mock_export.csv")
    }

    // MARK: - ExportServiceProtocol Implementation

    func exportToCSV(transactions: [Transaction]) async throws -> URL {
        // Simulate delay if configured
        if exportDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(exportDelay * 1_000_000_000))
        }

        // Record the call
        csvExportCalls.append(ExportToCSVCall(
            transactions: transactions,
            timestamp: Date()
        ))

        // Check for error injection
        if shouldThrowErrorOnCSV {
            throw csvErrorToThrow
        }

        // Create actual CSV file if requested
        if createActualCSVFile {
            let url = try createMockCSVFile(transactions: transactions)
            csvExportResult = url
            return url
        }

        // Return configured result
        guard let result = csvExportResult else {
            throw ExportError.exportFailed("No CSV export result configured")
        }

        return result
    }

    func exportToGoogleSheets(transactions: [Transaction]) async throws {
        // Simulate delay if configured
        if exportDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(exportDelay * 1_000_000_000))
        }

        // Record the call
        googleSheetsExportCalls.append(ExportToGoogleSheetsCall(
            transactions: transactions,
            timestamp: Date()
        ))

        // Check for error injection
        if shouldThrowErrorOnGoogleSheets {
            throw googleSheetsErrorToThrow
        }

        // Success - no return value
    }

    // MARK: - Helper Methods

    private func createMockCSVFile(transactions: [Transaction]) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "export_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Create CSV content
        var csvContent = "Date,Type,Amount,Category,Description,Account\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.transactionDate)
            let type = transaction.type.rawValue
            let amount = "\(transaction.amount)"
            let category = transaction.category?.name ?? ""
            let description = transaction.description.replacingOccurrences(of: ",", with: ";")
            let account = transaction.fromAccount?.displayName ?? transaction.toAccount?.displayName ?? ""

            csvContent += "\(date),\(type),\(amount),\(category),\(description),\(account)\n"
        }

        // Write to file
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    // MARK: - Test Verification Methods

    /// Returns whether CSV export was called
    var wasCSVExportCalled: Bool {
        !csvExportCalls.isEmpty
    }

    /// Returns the number of times CSV export was called
    var csvExportCallCount: Int {
        csvExportCalls.count
    }

    /// Returns whether Google Sheets export was called
    var wasGoogleSheetsExportCalled: Bool {
        !googleSheetsExportCalls.isEmpty
    }

    /// Returns the number of times Google Sheets export was called
    var googleSheetsExportCallCount: Int {
        googleSheetsExportCalls.count
    }

    /// Returns the most recent CSV export call
    var lastCSVExportCall: ExportToCSVCall? {
        csvExportCalls.last
    }

    /// Returns the most recent Google Sheets export call
    var lastGoogleSheetsExportCall: ExportToGoogleSheetsCall? {
        googleSheetsExportCalls.last
    }

    /// Returns the total number of transactions exported via CSV
    var totalTransactionsExportedToCSV: Int {
        csvExportCalls.reduce(0) { $0 + $1.transactions.count }
    }

    /// Returns the total number of transactions exported to Google Sheets
    var totalTransactionsExportedToGoogleSheets: Int {
        googleSheetsExportCalls.reduce(0) { $0 + $1.transactions.count }
    }

    /// Clears all call history
    func clearCallHistory() {
        csvExportCalls.removeAll()
        googleSheetsExportCalls.removeAll()
    }

    /// Resets all configuration and call history
    func reset() {
        csvExportCalls.removeAll()
        googleSheetsExportCalls.removeAll()
        shouldThrowErrorOnCSV = false
        shouldThrowErrorOnGoogleSheets = false
        exportDelay = 0
        createActualCSVFile = false

        let tempDir = FileManager.default.temporaryDirectory
        csvExportResult = tempDir.appendingPathComponent("mock_export.csv")
    }

    // MARK: - Verification Helpers

    /// Verifies that a specific number of transactions were exported to CSV
    func wasCSVExportCalled(withTransactionCount count: Int) -> Bool {
        csvExportCalls.contains { $0.transactions.count == count }
    }

    /// Verifies that a specific number of transactions were exported to Google Sheets
    func wasGoogleSheetsExportCalled(withTransactionCount count: Int) -> Bool {
        googleSheetsExportCalls.contains { $0.transactions.count == count }
    }

    /// Returns all CSV export calls within a date range
    func csvExportCalls(since date: Date) -> [ExportToCSVCall] {
        csvExportCalls.filter { $0.timestamp >= date }
    }

    /// Returns all Google Sheets export calls within a date range
    func googleSheetsExportCalls(since date: Date) -> [ExportToGoogleSheetsCall] {
        googleSheetsExportCalls.filter { $0.timestamp >= date }
    }

    // MARK: - Preset Configurations

    /// Configures the service to always fail CSV exports
    func alwaysFailCSVExport(withError error: Error? = nil) {
        shouldThrowErrorOnCSV = true
        if let error = error {
            csvErrorToThrow = error
        }
    }

    /// Configures the service to always fail Google Sheets exports
    func alwaysFailGoogleSheetsExport(withError error: Error? = nil) {
        shouldThrowErrorOnGoogleSheets = true
        if let error = error {
            googleSheetsErrorToThrow = error
        }
    }

    /// Configures the service to always succeed with actual CSV file creation
    func alwaysCreateActualCSVFiles() {
        createActualCSVFile = true
        shouldThrowErrorOnCSV = false
    }

    /// Simulates slow export operations
    func useSlowExportMode(delay: TimeInterval = 2.0) {
        exportDelay = delay
    }

    /// Simulates fast export operations
    func useFastExportMode() {
        exportDelay = 0
    }
}

// MARK: - Export Errors

enum ExportError: Error, LocalizedError {
    case exportFailed(String)
    case googleSheetsAuthenticationFailed
    case googleSheetsAPIError
    case fileCreationFailed
    case insufficientPermissions

    var errorDescription: String? {
        switch self {
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .googleSheetsAuthenticationFailed:
            return "Google Sheets authentication failed"
        case .googleSheetsAPIError:
            return "Google Sheets API error"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .insufficientPermissions:
            return "Insufficient permissions to export"
        }
    }
}
