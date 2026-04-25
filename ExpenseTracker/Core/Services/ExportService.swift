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

        // US Letter (612×792pt) — share-friendly default.
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: UIGraphicsPDFRendererFormat())

        let totals = Self.totals(for: transactions)
        let categoryStats = Self.categoryBreakdown(for: transactions, total: totals.spent)
        let dailyStats = Self.dailyBreakdown(for: transactions)
        // Use the app's effective locale so the PDF header date matches the
        // localized PDF strings (English bundle → English date, etc.).
        let exportLocaleId = Bundle.main.preferredLocalizations.first ?? "uk_UA"
        let displayDate = Formatters.dateString(
            Date(),
            dateStyle: .long,
            timeStyle: .short,
            localeIdentifier: exportLocaleId
        )
        let report = PDFReport(
            transactions: transactions.sorted { $0.transactionDate > $1.transactionDate },
            totals: totals,
            categoryStats: categoryStats,
            dailyStats: dailyStats,
            exportedAt: displayDate
        )

        let pdfData = renderer.pdfData { ctx in
            Self.renderReport(report, page: page, ctx: ctx)
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

    private struct CategorySlice {
        let name: String
        let colorHex: String
        let amount: Decimal
        let percentage: Double
    }

    private struct DailyBucket {
        let date: Date
        let amount: Decimal
    }

    private struct PDFReport {
        let transactions: [Transaction]
        let totals: MonthTotals
        let categoryStats: [CategorySlice]
        let dailyStats: [DailyBucket]
        let exportedAt: String
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

    private static func categoryBreakdown(for transactions: [Transaction], total: Decimal) -> [CategorySlice] {
        guard total > 0 else { return [] }
        var bucket: [String: (name: String, colorHex: String, amount: Decimal)] = [:]
        for tx in transactions where !tx.isSplitChild
            && (tx.type == .expense || tx.type == .transferOut) {
            guard let category = tx.category else { continue }
            let key = category.name
            let prior = bucket[key]?.amount ?? 0
            bucket[key] = (
                name: category.displayName,
                colorHex: category.colorHex,
                amount: prior + abs(tx.effectiveAmount)
            )
        }
        let totalDouble = Double(truncating: NSDecimalNumber(decimal: total))
        return bucket.values
            .map { entry in
                CategorySlice(
                    name: entry.name,
                    colorHex: entry.colorHex,
                    amount: entry.amount,
                    percentage: Double(truncating: NSDecimalNumber(decimal: entry.amount)) / totalDouble * 100
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    private static func dailyBreakdown(for transactions: [Transaction]) -> [DailyBucket] {
        let calendar = Calendar.current
        var buckets: [Date: Decimal] = [:]
        for tx in transactions where !tx.isSplitChild
            && (tx.type == .expense || tx.type == .transferOut) {
            let day = calendar.startOfDay(for: tx.transactionDate)
            buckets[day, default: 0] += abs(tx.effectiveAmount)
        }
        return buckets
            .map { DailyBucket(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
            .suffix(30)
            .map { $0 }
    }

    // MARK: - PDF design tokens

    private static let pdfHoney = UIColor(red: 228/255, green: 179/255, blue: 74/255, alpha: 1)
    private static let pdfInk = UIColor(red: 15/255, green: 23/255, blue: 18/255, alpha: 1)
    private static let pdfBone = UIColor(red: 245/255, green: 241/255, blue: 232/255, alpha: 1)
    private static let pdfSecondary = UIColor(white: 0.29, alpha: 1)
    private static let pdfExpense = UIColor(red: 192/255, green: 48/255, blue: 39/255, alpha: 1)
    private static let pdfIncome = UIColor(red: 31/255, green: 136/255, blue: 64/255, alpha: 1)

    // MARK: - Top-level paginator

    private static func renderReport(_ report: PDFReport, page: CGRect, ctx: UIGraphicsPDFRendererContext) {
        let margin: CGFloat = 40
        let footerHeight: CGFloat = 24
        let pageBottom = page.height - margin - footerHeight

        // Pre-compute total page count so the footer can show "Page X of Y".
        let firstPageBudget = pageBottom - (margin + 320) // header+title+kpis+rings+bars+listHeader
        let rowLineHeight: CGFloat = 16
        let firstPageRows = max(0, Int(firstPageBudget / rowLineHeight))
        let subsequentBudget = pageBottom - (margin + 60) // slim header + list header
        let subsequentRows = max(1, Int(subsequentBudget / rowLineHeight))
        let overflow = max(0, report.transactions.count - firstPageRows)
        let totalPages = 1 + Int((Double(overflow) / Double(subsequentRows)).rounded(.up))

        // — Page 1 —
        ctx.beginPage()
        var y: CGFloat = margin
        y = drawHeader(at: y, in: page, margin: margin, exportedAt: report.exportedAt)
        y = drawTitleBlock(at: y, in: page, margin: margin, transactionCount: report.transactions.count)
        y = drawKPIs(at: y, in: page, margin: margin, totals: report.totals)
        y = drawDashedBreak(at: y, in: page, margin: margin)
        y = drawCategoryRings(at: y, in: page, margin: margin, slices: report.categoryStats)
        y = drawDashedBreak(at: y, in: page, margin: margin)
        y = drawDailyBars(at: y, in: page, margin: margin, buckets: report.dailyStats)
        y = drawDashedBreak(at: y, in: page, margin: margin)
        y = drawListHeader(at: y, in: page, margin: margin)

        let firstSlice = Array(report.transactions.prefix(firstPageRows))
        drawTransactionRows(firstSlice, startingAt: y, in: page, margin: margin)
        drawFooter(in: page, margin: margin, page: 1, of: totalPages)

        // — Subsequent pages —
        var consumed = firstPageRows
        var pageIndex = 2
        while consumed < report.transactions.count {
            ctx.beginPage()
            var py = margin
            py = drawSlimHeader(at: py, in: page, margin: margin, exportedAt: report.exportedAt)
            py = drawListHeader(
                at: py,
                in: page,
                margin: margin,
                suffix: NSLocalizedString("export.pdf.continuationSuffix", comment: "")
            )
            let slice = Array(report.transactions[consumed..<min(consumed + subsequentRows, report.transactions.count)])
            drawTransactionRows(slice, startingAt: py, in: page, margin: margin)
            drawFooter(in: page, margin: margin, page: pageIndex, of: totalPages)
            consumed += subsequentRows
            pageIndex += 1
        }
    }

    // MARK: - PDF section drawing

    private static func drawHeader(at startY: CGFloat, in page: CGRect, margin: CGFloat, exportedAt: String) -> CGFloat {
        let monogramFont = UIFont(name: "Charter-Black", size: 26)
            ?? UIFont(name: "Iowan Old Style-Bold", size: 26)
            ?? UIFont.boldSystemFont(ofSize: 26)

        let monogram = NSMutableAttributedString(
            string: "Б",
            attributes: [.font: monogramFont, .foregroundColor: pdfInk]
        )
        monogram.append(NSAttributedString(
            string: ".",
            attributes: [.font: monogramFont, .foregroundColor: pdfHoney]
        ))
        monogram.draw(at: CGPoint(x: margin, y: startY))

        let exportedFormat = NSLocalizedString("export.pdf.exported %@", comment: "")
        let exportedLine = String(format: exportedFormat, exportedAt)
        let exportedText = NSAttributedString(
            string: "banka.app\n\(exportedLine)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: pdfSecondary
            ]
        )
        let contentWidth = page.width - margin * 2
        let exportedSize = exportedText.boundingRect(
            with: CGSize(width: contentWidth, height: 40),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).size
        exportedText.draw(at: CGPoint(
            x: page.width - margin - exportedSize.width,
            y: startY + 4
        ))

        var y = startY + 40
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: y))
        rule.addLine(to: CGPoint(x: page.width - margin, y: y))
        rule.lineWidth = 2
        pdfInk.setStroke()
        rule.stroke()
        y += 16
        return y
    }

    private static func drawSlimHeader(at startY: CGFloat, in page: CGRect, margin: CGFloat, exportedAt: String) -> CGFloat {
        let mono = NSMutableAttributedString(string: "Б", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: pdfInk
        ])
        mono.append(NSAttributedString(string: ".", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: pdfHoney
        ]))
        mono.draw(at: CGPoint(x: margin, y: startY))

        let exported = NSAttributedString(
            string: "Banka · \(exportedAt)", // brand wordmark — domain/wordmark stays consistent across locales
            attributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: pdfSecondary]
        )
        let size = exported.size()
        exported.draw(at: CGPoint(x: page.width - margin - size.width, y: startY + 4))

        var y = startY + 22
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: y))
        rule.addLine(to: CGPoint(x: page.width - margin, y: y))
        rule.lineWidth = 0.5
        pdfInk.setStroke()
        rule.stroke()
        y += 12
        return y
    }

    private static func drawTitleBlock(at startY: CGFloat, in page: CGRect, margin: CGFloat, transactionCount: Int) -> CGFloat {
        let titleFont = UIFont(name: "Charter-Black", size: 22)
            ?? UIFont.boldSystemFont(ofSize: 22)
        let title = NSAttributedString(
            string: NSLocalizedString("export.pdf.title", comment: ""),
            attributes: [.font: titleFont, .foregroundColor: pdfInk]
        )
        title.draw(at: CGPoint(x: margin, y: startY))

        let subtitle = NSAttributedString(
            string: "\(transactionCount) " + NSLocalizedString("export.pdf.transactionCount", comment: ""),
            attributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: pdfSecondary]
        )
        subtitle.draw(at: CGPoint(x: margin, y: startY + 28))
        return startY + 52
    }

    private static func drawKPIs(at startY: CGFloat, in page: CGRect, margin: CGFloat, totals: MonthTotals) -> CGFloat {
        let contentWidth = page.width - margin * 2
        let tileGap: CGFloat = 12
        let tileWidth = (contentWidth - tileGap * 2) / 3
        let tileHeight: CGFloat = 64

        let kpis: [(label: String, value: Decimal, color: UIColor, signed: Bool)] = [
            (NSLocalizedString("export.pdf.spent", comment: ""), totals.spent, pdfExpense, false),
            (NSLocalizedString("export.pdf.earned", comment: ""), totals.earned, pdfIncome, false),
            (NSLocalizedString("export.pdf.net", comment: ""), totals.net, pdfInk, true)
        ]

        for (index, kpi) in kpis.enumerated() {
            let x = margin + CGFloat(index) * (tileWidth + tileGap)
            let tileRect = CGRect(x: x, y: startY, width: tileWidth, height: tileHeight)
            pdfBone.setFill()
            UIBezierPath(roundedRect: tileRect, cornerRadius: 8).fill()

            NSAttributedString(
                string: kpi.label.uppercased(),
                attributes: [
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: pdfSecondary,
                    .kern: 0.5
                ]
            ).draw(at: CGPoint(x: x + 12, y: startY + 12))

            let valueString = Formatters.decimalString(kpi.value, minFractionDigits: 0, maxFractionDigits: 2, locale: Locale(identifier: "uk_UA"))
            let prefix = kpi.signed && kpi.value > 0 ? "+" : (kpi.value < 0 ? "−" : "")
            NSAttributedString(
                string: "\(prefix)\(valueString)",
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium),
                    .foregroundColor: kpi.color
                ]
            ).draw(at: CGPoint(x: x + 12, y: startY + 30))
        }

        // "All amounts in ₴" caption
        let caption = NSAttributedString(
            string: NSLocalizedString("export.pdf.inCurrency", comment: ""),
            attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: pdfSecondary]
        )
        caption.draw(at: CGPoint(x: margin, y: startY + tileHeight + 6))
        return startY + tileHeight + 24
    }

    private static func drawDashedBreak(at startY: CGFloat, in page: CGRect, margin: CGFloat) -> CGFloat {
        let dashed = UIBezierPath()
        dashed.move(to: CGPoint(x: margin, y: startY))
        dashed.addLine(to: CGPoint(x: page.width - margin, y: startY))
        dashed.lineWidth = 2
        dashed.setLineDash([6, 6], count: 2, phase: 0)
        pdfInk.setStroke()
        dashed.stroke()
        return startY + 18
    }

    private static func drawCategoryRings(
        at startY: CGFloat,
        in page: CGRect,
        margin: CGFloat,
        slices: [CategorySlice]
    ) -> CGFloat {
        guard !slices.isEmpty else { return startY }

        let header = NSAttributedString(
            string: NSLocalizedString("export.pdf.byCategory", comment: "").uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: pdfSecondary,
                .kern: 0.5
            ]
        )
        header.draw(at: CGPoint(x: margin, y: startY))

        // Draw concentric rings on the left, legend on the right.
        let chartSize: CGFloat = 100
        let chartCenter = CGPoint(x: margin + chartSize / 2, y: startY + 22 + chartSize / 2)
        let ringStroke: CGFloat = 9
        let ringGap: CGFloat = 3

        let rings = Array(slices.prefix(4))
        for (i, slice) in rings.enumerated() {
            let radius = (chartSize - ringStroke) / 2 - CGFloat(i) * (ringStroke + ringGap)
            guard radius > 4 else { break }
            let rect = CGRect(
                x: chartCenter.x - radius,
                y: chartCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let categoryColor = uiColor(fromHex: slice.colorHex)

            // Background ring (15%)
            let bg = UIBezierPath(ovalIn: rect)
            bg.lineWidth = ringStroke
            categoryColor.withAlphaComponent(0.15).setStroke()
            bg.stroke()

            // Foreground arc — clamp 0…1
            let fraction = max(0, min(slice.percentage / 100.0, 1))
            let endAngle = -CGFloat.pi / 2 + CGFloat(fraction) * 2 * .pi
            let arc = UIBezierPath(
                arcCenter: chartCenter,
                radius: radius,
                startAngle: -CGFloat.pi / 2,
                endAngle: endAngle,
                clockwise: true
            )
            arc.lineWidth = ringStroke
            arc.lineCapStyle = .round
            categoryColor.setStroke()
            arc.stroke()
        }

        // Legend — top 5 categories
        let legendStartX = margin + chartSize + 32
        let legendWidth = page.width - margin - legendStartX
        var legendY = startY + 22
        for slice in slices.prefix(5) {
            let dot = UIBezierPath(
                ovalIn: CGRect(x: legendStartX, y: legendY + 4, width: 8, height: 8)
            )
            uiColor(fromHex: slice.colorHex).setFill()
            dot.fill()

            let nameStr = NSAttributedString(
                string: slice.name,
                attributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: pdfInk]
            )
            nameStr.draw(at: CGPoint(x: legendStartX + 14, y: legendY))

            let pctStr = NSAttributedString(
                string: String(format: "%.1f%%", slice.percentage),
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: pdfSecondary
                ]
            )
            let pctSize = pctStr.size()
            pctStr.draw(at: CGPoint(x: legendStartX + legendWidth - pctSize.width, y: legendY))

            legendY += 16
        }

        return startY + max(chartSize + 28, CGFloat(min(slices.count, 5)) * 16 + 30)
    }

    private static func drawDailyBars(
        at startY: CGFloat,
        in page: CGRect,
        margin: CGFloat,
        buckets: [DailyBucket]
    ) -> CGFloat {
        guard !buckets.isEmpty else { return startY }

        let header = NSAttributedString(
            string: NSLocalizedString("export.pdf.dailySpend", comment: "").uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: pdfSecondary,
                .kern: 0.5
            ]
        )
        header.draw(at: CGPoint(x: margin, y: startY))

        let chartTop = startY + 22
        let chartHeight: CGFloat = 60
        let contentWidth = page.width - margin * 2
        let maxAmount = buckets.map { $0.amount }.max() ?? 0
        guard maxAmount > 0 else { return startY + 22 + chartHeight + 8 }

        let avgAmount = buckets.reduce(Decimal(0)) { $0 + $1.amount } / Decimal(buckets.count)
        let avgFraction = Double(truncating: NSDecimalNumber(decimal: avgAmount))
            / Double(truncating: NSDecimalNumber(decimal: maxAmount))

        let barCount = buckets.count
        let barGap: CGFloat = 2
        let barWidth = max((contentWidth - CGFloat(barCount - 1) * barGap) / CGFloat(barCount), 2)

        // Bars — ink fill at 88% opacity
        for (i, bucket) in buckets.enumerated() {
            let amountDouble = Double(truncating: NSDecimalNumber(decimal: bucket.amount))
            let maxDouble = Double(truncating: NSDecimalNumber(decimal: maxAmount))
            let h = chartHeight * CGFloat(amountDouble / maxDouble)
            let x = margin + CGFloat(i) * (barWidth + barGap)
            let rect = CGRect(x: x, y: chartTop + chartHeight - h, width: barWidth, height: h)
            pdfInk.withAlphaComponent(0.88).setFill()
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: 1.5, height: 1.5)
            ).fill()
        }

        // Average line — honey dashed
        let avgY = chartTop + chartHeight - chartHeight * CGFloat(avgFraction)
        let avgLine = UIBezierPath()
        avgLine.move(to: CGPoint(x: margin, y: avgY))
        avgLine.addLine(to: CGPoint(x: page.width - margin, y: avgY))
        avgLine.lineWidth = 1.5
        avgLine.setLineDash([4, 4], count: 2, phase: 0)
        pdfHoney.setStroke()
        avgLine.stroke()

        // "avg X ₴/day" caption right of the line
        let avgString = Formatters.currencyStringUAH(amount: avgAmount, minFractionDigits: 0, maxFractionDigits: 0)
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: pdfHoney
        ]
        let avgFormat = NSLocalizedString("export.pdf.avgPerDay %@", comment: "")
        let avgCaption = NSAttributedString(
            string: String(format: avgFormat, avgString),
            attributes: captionAttrs
        )
        let captionSize = avgCaption.size()
        // Draw background rect for legibility against bars
        let captionRect = CGRect(
            x: page.width - margin - captionSize.width - 6,
            y: avgY - captionSize.height - 1,
            width: captionSize.width + 6,
            height: captionSize.height + 2
        )
        UIColor.white.withAlphaComponent(0.85).setFill()
        UIBezierPath(roundedRect: captionRect, cornerRadius: 2).fill()
        avgCaption.draw(at: CGPoint(x: captionRect.minX + 3, y: captionRect.minY + 1))

        return chartTop + chartHeight + 12
    }

    private static func drawListHeader(at startY: CGFloat, in page: CGRect, margin: CGFloat, suffix: String = "") -> CGFloat {
        let listHeader = NSAttributedString(
            string: (NSLocalizedString("export.pdf.transactions", comment: "") + suffix).uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: pdfSecondary,
                .kern: 0.5
            ]
        )
        listHeader.draw(at: CGPoint(x: margin, y: startY))
        return startY + 18
    }

    private static func drawTransactionRows(
        _ transactions: [Transaction],
        startingAt startY: CGFloat,
        in page: CGRect,
        margin: CGFloat
    ) {
        // Match per-row dates to the PDF's localized strings.
        let exportLocaleId = Bundle.main.preferredLocalizations.first ?? "uk_UA"
        let dateFormatter = Formatters.dateFormatter(dateStyle: .short, timeStyle: .none, localeIdentifier: exportLocaleId)
        let rowFont = UIFont.systemFont(ofSize: 11)
        let rowAmountFont = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let rowLineHeight: CGFloat = 16
        let contentWidth = page.width - margin * 2
        var y = startY

        for tx in transactions {
            let dateText = dateFormatter.string(from: tx.transactionDate)
            let categoryName = tx.category?.displayName ?? ""
            let descriptionText = tx.description
            let amountColor: UIColor = (tx.type == .expense || tx.type == .transferOut) ? pdfExpense : pdfIncome
            let amountString = Formatters.currencyStringUAH(amount: tx.effectiveAmount)
            let amountSigned = (tx.type == .expense || tx.type == .transferOut) ? "−\(amountString)" : "+\(amountString)"

            let leftAttrs: [NSAttributedString.Key: Any] = [.font: rowFont, .foregroundColor: pdfInk]
            let leftText = NSMutableAttributedString(
                string: "\(dateText)  ",
                attributes: [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: pdfSecondary
                ]
            )
            leftText.append(NSAttributedString(string: descriptionText, attributes: leftAttrs))
            if !categoryName.isEmpty {
                leftText.append(NSAttributedString(
                    string: "  · \(categoryName)",
                    attributes: [.font: rowFont, .foregroundColor: pdfSecondary]
                ))
            }
            leftText.draw(in: CGRect(x: margin, y: y, width: contentWidth - 100, height: rowLineHeight))

            let amount = NSAttributedString(
                string: amountSigned,
                attributes: [.font: rowAmountFont, .foregroundColor: amountColor]
            )
            let amountSize = amount.size()
            amount.draw(at: CGPoint(x: page.width - margin - amountSize.width, y: y))

            y += rowLineHeight
        }
    }

    private static func drawFooter(in page: CGRect, margin: CGFloat, page pageNumber: Int, of totalPages: Int) {
        let footerY = page.height - margin
        let pageInfoFont = UIFont.systemFont(ofSize: 9)
        let pageInfoAttrs: [NSAttributedString.Key: Any] = [
            .font: pageInfoFont,
            .foregroundColor: pdfSecondary
        ]
        let pageFormat = NSLocalizedString("export.pdf.pageOf %lld %lld", comment: "")
        let leftCaption = NSAttributedString(
            string: String(format: pageFormat, pageNumber, totalPages),
            attributes: pageInfoAttrs
        )
        leftCaption.draw(at: CGPoint(x: margin, y: footerY - 14))

        let rightCaption = NSAttributedString(
            string: NSLocalizedString("export.pdf.footer", comment: ""),
            attributes: pageInfoAttrs
        )
        let rightSize = rightCaption.size()
        rightCaption.draw(at: CGPoint(x: page.width - margin - rightSize.width, y: footerY - 14))
    }

    // MARK: - PDF helpers

    private static func uiColor(fromHex hex: String) -> UIColor {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch normalized.count {
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8) & 0xFF) / 255
            b = CGFloat(int & 0xFF) / 255
        case 3:
            r = CGFloat((int >> 8) * 17) / 255
            g = CGFloat((int >> 4 & 0xF) * 17) / 255
            b = CGFloat((int & 0xF) * 17) / 255
        default:
            return pdfInk
        }
        return UIColor(red: r, green: g, blue: b, alpha: 1)
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
