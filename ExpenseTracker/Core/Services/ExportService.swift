//
//  ExportService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import os

private let exportLogger = Logger(subsystem: "com.expensetracker", category: "Export")

protocol ExportServiceProtocol: Sendable {
    func exportToCSV(transactions: [Transaction]) async throws -> URL
    func exportToGoogleSheets(transactions: [Transaction]) async throws
}

// Stateless — no mutable storage, methods only touch the filesystem and
// the deterministic output path. Safe to pass across actor boundaries.
final class ExportService: ExportServiceProtocol, @unchecked Sendable {

    func exportToCSV(transactions: [Transaction]) async throws -> URL {
        // Filename per Banka design spec: banka-YYYY-MM.csv (lowercase, ISO
        // year-month, no spaces). The two formats — PDF and CSV — must share
        // this scheme. A short UUID disambiguates simultaneous re-exports
        // without breaking the human-readable prefix.
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let yearMonth = monthFormatter.string(from: Date())
        let disambiguator = UUID().uuidString.prefix(8)
        let fileName = "banka-\(yearMonth)-\(disambiguator).csv"

        // Write to a dedicated subdirectory in the temporary directory to avoid conflicts
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        cleanupOldExports(in: exportDir)

        let fileURL = exportDir.appendingPathComponent(fileName)

        var csvText = "Date,Type,Amount,Category,Description,Account\n"

        let dateFormatter = Formatters.dateFormatter(dateStyle: .short, timeStyle: .none, localeIdentifier: "uk_UA")

        for transaction in transactions {
            let date = escapeCSVField(dateFormatter.string(from: transaction.transactionDate))
            let type = escapeCSVField(transaction.type.rawValue)
            let amount = escapeCSVField("\(transaction.amount)")
            let category = escapeCSVField(transaction.category?.displayName ?? "")
            let description = escapeCSVField(transaction.description)
            let account = escapeCSVField(transaction.fromAccount?.displayName ?? transaction.toAccount?.displayName ?? "")

            csvText += "\(date),\(type),\(amount),\(category),\(description),\(account)\n"
        }

        try csvText.write(to: fileURL, atomically: true, encoding: .utf8)

        // Apply file protection so the file is encrypted when device is locked
        try (fileURL as NSURL).setResourceValue(
            URLFileProtection.complete,
            forKey: .fileProtectionKey
        )

        return fileURL
    }

    func exportToGoogleSheets(transactions: [Transaction]) async throws {
        // Placeholder hook for future Google Sheets integration
        exportLogger.info("Exporting \(transactions.count) transactions to Google Sheets")
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

        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        for file in files {
            guard let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = attributes.creationDate,
                  creationDate < fiveMinutesAgo else { continue }
            do {
                try fileManager.removeItem(at: file)
            } catch {
                exportLogger.warning("Failed to clean up export file \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
