//
//  ExportService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import os
import UIKit

private let exportLogger = Logger(subsystem: "com.expensetracker", category: "Export")

protocol ExportServiceProtocol: Sendable {
    func exportToCSV(transactions: [Transaction]) async throws -> URL
    func exportToPDF(transactions: [Transaction]) async throws -> URL
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

    func exportToPDF(transactions: [Transaction]) async throws -> URL {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let yearMonth = monthFormatter.string(from: Date())
        let disambiguator = UUID().uuidString.prefix(8)
        let fileName = "banka-\(yearMonth)-\(disambiguator).pdf"

        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        cleanupOldExports(in: exportDir)

        let fileURL = exportDir.appendingPathComponent(fileName)

        // US Letter (612×792pt) — share-friendly default. The design pack
        // shows a tighter aspect, but Letter prints clean and reads well
        // in iOS Files / Mail / AirDrop preview.
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: UIGraphicsPDFRendererFormat())

        let totals = Self.totals(for: transactions)
        let displayDate = Formatters.dateString(Date(), dateStyle: .long, timeStyle: .short)
        let pdfData = renderer.pdfData { ctx in
            ctx.beginPage()
            Self.drawPDF(
                in: page,
                transactions: transactions,
                totals: totals,
                exportedAt: displayDate
            )
        }

        try pdfData.write(to: fileURL, options: [.atomic, .completeFileProtection])
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

    // MARK: - PDF rendering

    private struct MonthTotals {
        let spent: Decimal
        let earned: Decimal
        var net: Decimal { earned - spent }
    }

    private static func totals(for transactions: [Transaction]) -> MonthTotals {
        var spent: Decimal = 0
        var earned: Decimal = 0
        for tx in transactions {
            // Skip child split rows — parents already represent the flow.
            if tx.isSplitChild { continue }
            switch tx.type {
            case .expense, .transferOut:
                spent += abs(tx.effectiveAmount)
            case .income, .transferIn:
                earned += abs(tx.effectiveAmount)
            }
        }
        return MonthTotals(spent: spent, earned: earned)
    }

    private static func drawPDF(
        in page: CGRect,
        transactions: [Transaction],
        totals: MonthTotals,
        exportedAt: String
    ) {
        let margin: CGFloat = 40
        let contentWidth = page.width - margin * 2
        var y: CGFloat = margin

        // Header — serif Б monogram + Banka wordmark + exported date
        let monogramFont = UIFont(name: "Charter-Black", size: 26)
            ?? UIFont(name: "Iowan Old Style-Bold", size: 26)
            ?? UIFont(descriptor: UIFontDescriptor()
                .withFamily("Georgia")
                .withSymbolicTraits(.traitBold) ?? UIFontDescriptor(),
                size: 26)
        let honey = UIColor(red: 228/255, green: 179/255, blue: 74/255, alpha: 1)
        let ink = UIColor(red: 15/255, green: 23/255, blue: 18/255, alpha: 1)
        let secondaryText = UIColor(white: 0.29, alpha: 1)

        // "Б." with the dot in honey
        let monogram = NSMutableAttributedString(
            string: "Б",
            attributes: [.font: monogramFont, .foregroundColor: ink]
        )
        monogram.append(NSAttributedString(
            string: ".",
            attributes: [.font: monogramFont, .foregroundColor: honey]
        ))
        monogram.draw(at: CGPoint(x: margin, y: y))

        let exportedText = NSAttributedString(
            string: "banka.app\nExported \(exportedAt)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: secondaryText
            ]
        )
        let exportedSize = exportedText.boundingRect(
            with: CGSize(width: contentWidth, height: 40),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).size
        exportedText.draw(at: CGPoint(
            x: page.width - margin - exportedSize.width,
            y: y + 4
        ))

        y += 40

        // Underline rule
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: y))
        rule.addLine(to: CGPoint(x: page.width - margin, y: y))
        rule.lineWidth = 2
        ink.setStroke()
        rule.stroke()

        y += 24

        // Title
        let titleFont = UIFont(name: "Charter-Black", size: 22)
            ?? UIFont.systemFont(ofSize: 22, weight: .bold)
        let title = NSAttributedString(
            string: NSLocalizedString("export.pdf.title", comment: ""),
            attributes: [.font: titleFont, .foregroundColor: ink]
        )
        title.draw(at: CGPoint(x: margin, y: y))
        y += 32

        let subtitle = NSAttributedString(
            string: "\(transactions.count) "
                + NSLocalizedString("export.pdf.transactionCount", comment: ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: secondaryText
            ]
        )
        subtitle.draw(at: CGPoint(x: margin, y: y))
        y += 28

        // KPI tiles — Spent / Earned / Net. Currency hoisted out per
        // design (avoids ₴ orphaning when amounts wrap).
        let tileGap: CGFloat = 12
        let tileWidth = (contentWidth - tileGap * 2) / 3
        let tileHeight: CGFloat = 64
        let bone = UIColor(red: 245/255, green: 241/255, blue: 232/255, alpha: 1)
        let expense = UIColor(red: 192/255, green: 48/255, blue: 39/255, alpha: 1)
        let income = UIColor(red: 31/255, green: 136/255, blue: 64/255, alpha: 1)

        let kpis: [(label: String, value: Decimal, color: UIColor)] = [
            (NSLocalizedString("export.pdf.spent", comment: ""), totals.spent, expense),
            (NSLocalizedString("export.pdf.earned", comment: ""), totals.earned, income),
            (NSLocalizedString("export.pdf.net", comment: ""), totals.net, ink)
        ]

        for (index, kpi) in kpis.enumerated() {
            let x = margin + CGFloat(index) * (tileWidth + tileGap)
            let tileRect = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
            let tilePath = UIBezierPath(roundedRect: tileRect, cornerRadius: 8)
            bone.setFill()
            tilePath.fill()

            let label = NSAttributedString(
                string: kpi.label.uppercased(),
                attributes: [
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: secondaryText,
                    .kern: 0.5
                ]
            )
            label.draw(at: CGPoint(x: x + 12, y: y + 12))

            let valueString = Formatters.decimalString(kpi.value, minFractionDigits: 0, maxFractionDigits: 2, locale: Locale(identifier: "uk_UA"))
            let prefix = kpi.value > 0 && index != 0 ? "+" : (kpi.value < 0 ? "−" : "")
            let value = NSAttributedString(
                string: "\(prefix)\(valueString)",
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium),
                    .foregroundColor: kpi.color
                ]
            )
            value.draw(at: CGPoint(x: x + 12, y: y + 30))
        }

        y += tileHeight + 8

        // "in ₴" caption — currency hoisted out of the tiles
        let inUah = NSAttributedString(
            string: NSLocalizedString("export.pdf.inCurrency", comment: ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: secondaryText
            ]
        )
        inUah.draw(at: CGPoint(x: margin, y: y))

        y += 28

        // Ink dashed section break
        let dashed = UIBezierPath()
        dashed.move(to: CGPoint(x: margin, y: y))
        dashed.addLine(to: CGPoint(x: page.width - margin, y: y))
        dashed.lineWidth = 2
        dashed.setLineDash([6, 6], count: 2, phase: 0)
        ink.setStroke()
        dashed.stroke()

        y += 20

        // Transaction list — header
        let listHeader = NSAttributedString(
            string: NSLocalizedString("export.pdf.transactions", comment: "").uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: secondaryText,
                .kern: 0.5
            ]
        )
        listHeader.draw(at: CGPoint(x: margin, y: y))
        y += 18

        // Up to 24 most recent transactions on page 1; we don't paginate
        // yet — rest gets clipped. Full multi-page paginator can ship in
        // a follow-up once layout is locked in.
        let dateFormatter = Formatters.dateFormatter(dateStyle: .short, timeStyle: .none)
        let rowFont = UIFont.systemFont(ofSize: 11)
        let rowAmountFont = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let rowLineHeight: CGFloat = 16
        let rowsAvailable = max(0, Int((page.height - margin - y - 40) / rowLineHeight))
        let displayed = transactions
            .sorted { $0.transactionDate > $1.transactionDate }
            .prefix(rowsAvailable)

        for tx in displayed {
            let dateText = dateFormatter.string(from: tx.transactionDate)
            let categoryName = tx.category?.displayName ?? ""
            let descriptionText = tx.description
            let amountColor: UIColor = (tx.type == .expense || tx.type == .transferOut) ? expense : income
            let amountString = Formatters.currencyStringUAH(amount: tx.effectiveAmount)
            let amountSigned = (tx.type == .expense || tx.type == .transferOut) ? "−\(amountString)" : "+\(amountString)"

            // date · description · category — left half
            let leftAttrs: [NSAttributedString.Key: Any] = [
                .font: rowFont,
                .foregroundColor: ink
            ]
            let leftText = NSMutableAttributedString(
                string: "\(dateText)  ",
                attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: secondaryText]
            )
            leftText.append(NSAttributedString(string: descriptionText, attributes: leftAttrs))
            if !categoryName.isEmpty {
                leftText.append(NSAttributedString(
                    string: "  · \(categoryName)",
                    attributes: [.font: rowFont, .foregroundColor: secondaryText]
                ))
            }
            leftText.draw(in: CGRect(x: margin, y: y, width: contentWidth - 100, height: rowLineHeight))

            // amount — right-aligned
            let amount = NSAttributedString(
                string: amountSigned,
                attributes: [.font: rowAmountFont, .foregroundColor: amountColor]
            )
            let amountSize = amount.size()
            amount.draw(at: CGPoint(
                x: page.width - margin - amountSize.width,
                y: y
            ))

            y += rowLineHeight
        }

        // Footer
        let footerY = page.height - margin
        let footer = NSAttributedString(
            string: NSLocalizedString("export.pdf.footer", comment: ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: secondaryText
            ]
        )
        let footerSize = footer.size()
        footer.draw(at: CGPoint(
            x: (page.width - footerSize.width) / 2,
            y: footerY - 14
        ))
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
