//
//  Formatters.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 22.10.2025.
//

import Foundation

enum Formatters {
    private static let lock = NSLock()

    private static var currencyCache: [CurrencyFormatterKey: NumberFormatter] = [:]
    private static var decimalCache: [DecimalFormatterKey: NumberFormatter] = [:]
    private static var percentCache: [PercentFormatterKey: NumberFormatter] = [:]
    private static var dateCache: [DateFormatterKey: DateFormatter] = [:]

    // MARK: - Public API

    static func currencyStringUAH(amount: Decimal,
                                  minFractionDigits: Int = 0,
                                  maxFractionDigits: Int = 2) -> String {
        currencyString(amount: amount,
                       currencyCode: "UAH",
                       symbol: "₴",
                       minFractionDigits: minFractionDigits,
                       maxFractionDigits: maxFractionDigits)
    }

    static func currencyString(amount: Decimal,
                               currency: Currency,
                               minFractionDigits: Int = 0,
                               maxFractionDigits: Int = 2) -> String {
        currencyString(amount: amount,
                       currencyCode: currency.rawValue,
                       symbol: currency.symbol,
                       minFractionDigits: minFractionDigits,
                       maxFractionDigits: maxFractionDigits)
    }

    static func currencyString(amount: Decimal,
                               currencyCode: String,
                               symbol: String,
                               minFractionDigits: Int = 0,
                               maxFractionDigits: Int = 2) -> String {
        let formatter = currencyFormatter(currencyCode: currencyCode,
                                          symbol: symbol,
                                          minFractionDigits: minFractionDigits,
                                          maxFractionDigits: maxFractionDigits)
        let formatted = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(symbol)0"
        // Replace non-breaking space (U+00A0) with regular space (U+0020) for consistency
        return formatted.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    static func decimalString(_ value: Decimal,
                              minFractionDigits: Int = 0,
                              maxFractionDigits: Int = 2,
                              locale: Locale = Locale.current) -> String {
        let formatter = decimalFormatter(minFractionDigits: minFractionDigits,
                                         maxFractionDigits: maxFractionDigits,
                                         locale: locale)
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }

    static func percentString(_ value: Double,
                              maxFractionDigits: Int = 1) -> String {
        let formatter = percentFormatter(maxFractionDigits: maxFractionDigits)
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    static func dateString(_ date: Date,
                           dateStyle: DateFormatter.Style = .medium,
                           timeStyle: DateFormatter.Style = .none,
                           localeIdentifier: String = "uk_UA") -> String {
        let formatter = dateFormatter(dateStyle: dateStyle,
                                      timeStyle: timeStyle,
                                      localeIdentifier: localeIdentifier)
        return formatter.string(from: date)
    }

    // MARK: - Cached formatters

    static func currencyFormatter(for currency: Currency,
                                  minFractionDigits: Int = 0,
                                  maxFractionDigits: Int = 2) -> NumberFormatter {
        currencyFormatter(currencyCode: currency.rawValue,
                          symbol: currency.symbol,
                          minFractionDigits: minFractionDigits,
                          maxFractionDigits: maxFractionDigits)
    }

    static func currencyFormatter(currencyCode: String,
                                  symbol: String,
                                  minFractionDigits: Int,
                                  maxFractionDigits: Int) -> NumberFormatter {
        let key = CurrencyFormatterKey(code: currencyCode,
                                       symbol: symbol,
                                       minFractionDigits: minFractionDigits,
                                       maxFractionDigits: maxFractionDigits)

        lock.lock()
        defer { lock.unlock() }

        if let cached = currencyCache[key] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.currencySymbol = symbol
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits

        currencyCache[key] = formatter
        return formatter
    }

    static func decimalFormatter(minFractionDigits: Int = 0,
                                 maxFractionDigits: Int = 2,
                                 locale: Locale = Locale.current) -> NumberFormatter {
        let key = DecimalFormatterKey(minFractionDigits: minFractionDigits,
                                      maxFractionDigits: maxFractionDigits,
                                      localeIdentifier: locale.identifier)

        lock.lock()
        defer { lock.unlock() }

        if let cached = decimalCache[key] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.locale = locale
        formatter.usesGroupingSeparator = true
        formatter.isLenient = true

        decimalCache[key] = formatter
        return formatter
    }

    static func percentFormatter(maxFractionDigits: Int = 1) -> NumberFormatter {
        let key = PercentFormatterKey(maxFractionDigits: maxFractionDigits)

        lock.lock()
        defer { lock.unlock() }

        if let cached = percentCache[key] {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = 0

        percentCache[key] = formatter
        return formatter
    }

    static func dateFormatter(dateStyle: DateFormatter.Style = .medium,
                              timeStyle: DateFormatter.Style = .none,
                              localeIdentifier: String = "uk_UA") -> DateFormatter {
        let key = DateFormatterKey(dateStyle: dateStyle.rawValue,
                                   timeStyle: timeStyle.rawValue,
                                   localeIdentifier: localeIdentifier)

        lock.lock()
        defer { lock.unlock() }

        if let cached = dateCache[key] {
            return cached
        }

        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.timeStyle = timeStyle

        dateCache[key] = formatter
        return formatter
    }

    static func decimalValue(from string: String,
                             locale: Locale = Locale.current) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidateLocales: [Locale] = Array(
            [locale,
             Locale.current,
             Locale(identifier: "en_US"),
             Locale(identifier: "uk_UA")].uniqued { $0.identifier }
        )

        for candidate in candidateLocales {
            let formatter = decimalFormatter(minFractionDigits: 0,
                                             maxFractionDigits: 8,
                                             locale: candidate)
            if let number = formatter.number(from: trimmed) {
                return number.decimalValue
            }
        }

        guard let normalized = normalizeDecimalString(trimmed) else {
            return nil
        }

        return Decimal(string: normalized)
    }

    // MARK: - Helpers

    private static func normalizeDecimalString(_ value: String) -> String? {
        let sanitized = value
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")

        let decimalCandidates: [Character] = [",", "."]
        var decimalSeparator: Character?

        for separator in decimalCandidates {
            guard let index = sanitized.lastIndex(of: separator) else { continue }
            let fractionStart = sanitized.index(after: index)
            guard fractionStart <= sanitized.endIndex else { continue }
            let fractionalPart = sanitized[fractionStart...]
            guard !fractionalPart.isEmpty else { continue }
            let onlyDigits = fractionalPart.allSatisfy { $0.isWholeNumber }
            let digitsAfter = fractionalPart.filter { $0.isWholeNumber }.count
            if onlyDigits && digitsAfter > 0 && digitsAfter <= 2 {
                decimalSeparator = separator
                break
            }
        }

        var result = ""
        var decimalInserted = false

        for character in sanitized {
            if character.isWholeNumber {
                result.append(character)
            } else if let separator = decimalSeparator,
                      character == separator,
                      !decimalInserted {
                result.append(".")
                decimalInserted = true
            }
            // Ignore other characters (grouping separators)
        }

        return result.isEmpty ? nil : result
    }
}

// MARK: - Formatter Keys

private struct CurrencyFormatterKey: Hashable {
    let code: String
    let symbol: String
    let minFractionDigits: Int
    let maxFractionDigits: Int
}

private struct DecimalFormatterKey: Hashable {
    let minFractionDigits: Int
    let maxFractionDigits: Int
    let localeIdentifier: String
}

private struct PercentFormatterKey: Hashable {
    let maxFractionDigits: Int
}

private struct DateFormatterKey: Hashable {
    let dateStyle: UInt
    let timeStyle: UInt
    let localeIdentifier: String
}

private extension Sequence {
    func uniqued<Key: Hashable>(by keyPath: (Element) -> Key) -> [Element] {
        var seen: Set<Key> = []
        return self.filter { element in
            let key = keyPath(element)
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}
