//
//  ExportService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation

protocol ExportServiceProtocol {
    func exportToCSV(transactions: [Transaction]) async throws -> URL
    func exportToGoogleSheets(transactions: [Transaction]) async throws
}

final class ExportService: ExportServiceProtocol {
    private let repository: TransactionRepositoryProtocol

    init(repository: TransactionRepositoryProtocol) {
        self.repository = repository
    }

    func exportToCSV(transactions: [Transaction]) async throws -> URL {
        // Create a unique, filesystem-safe filename with high precision timestamp and UUID
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = isoFormatter.string(from: Date()) // e.g., 2025-11-22T22:00:05.123Z

        // Sanitize characters that can be problematic in filenames on some systems
        let safeTimestamp = timestamp
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")

        let uniqueSuffix = UUID().uuidString
        let fileName = "transactions_\(safeTimestamp)_\(uniqueSuffix).csv"

        // Write to a dedicated subdirectory in the temporary directory to avoid conflicts
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        cleanupOldExports(in: exportDir)

        let fileURL = exportDir.appendingPathComponent(fileName)

        var csvText = "Date,Type,Amount,Category,Description,Account\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        for transaction in transactions {
            let date = escapeCSVField(dateFormatter.string(from: transaction.transactionDate))
            let type = escapeCSVField(transaction.type.rawValue)
            let amount = escapeCSVField("\(transaction.amount)")
            let category = escapeCSVField(transaction.category?.name ?? "")
            let description = escapeCSVField(transaction.description)
            let account = escapeCSVField(transaction.fromAccount?.name ?? transaction.toAccount?.name ?? "")

            csvText += "\(date),\(type),\(amount),\(category),\(description),\(account)\n"
        }

        try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func exportToGoogleSheets(transactions: [Transaction]) async throws {
        // Placeholder hook for future Google Sheets integration
        print("Exporting \(transactions.count) transactions to Google Sheets")
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private func cleanupOldExports(in directory: URL) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }

        let oneHourAgo = Date().addingTimeInterval(-3600)
        for file in files {
            guard let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = attributes.creationDate,
                  creationDate < oneHourAgo else { continue }
            try? fileManager.removeItem(at: file)
        }
    }
}
