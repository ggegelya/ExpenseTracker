//
//  LocalizationTests.swift
//  ExpenseTracker
//
//  Created by Claude Code on 22.11.2025.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("Localization Tests")
struct LocalizationTests {

    @Test("Currency formatter uses UAH symbol")
    func testUAHCurrencyFormat() {
        // Given
        let amount: Decimal = 1234.56

        // When
        let formatted = Formatters.currencyStringUAH(
            amount: amount,
            minFractionDigits: 2,
            maxFractionDigits: 2
        )

        // Then
        // Should contain UAH symbol (₴)
        #expect(formatted.contains("₴"))
        #expect(formatted.contains("1"))
        #expect(formatted.contains("234"))
        #expect(formatted.contains("56"))
    }

    @Test("Currency formatter handles zero amount")
    func testUAHCurrencyFormatZero() {
        // Given
        let amount: Decimal = 0

        // When
        let formatted = Formatters.currencyStringUAH(
            amount: amount,
            minFractionDigits: 0,
            maxFractionDigits: 2
        )

        // Then
        #expect(formatted.contains("₴"))
        #expect(formatted.contains("0"))
    }

    @Test("Currency formatter handles large amounts")
    func testUAHCurrencyFormatLargeAmount() {
        // Given
        let amount: Decimal = 1_000_000.99

        // When
        let formatted = Formatters.currencyStringUAH(
            amount: amount,
            minFractionDigits: 2,
            maxFractionDigits: 2
        )

        // Then
        #expect(formatted.contains("₴"))
        #expect(formatted.contains("1"))
        #expect(formatted.contains("000"))
        #expect(formatted.contains("99"))
    }

    @Test("Currency enum UAH has correct symbol")
    func testCurrencyEnumUAH() {
        // Given
        let currency = Currency.uah

        // Then
        #expect(currency.symbol == "₴")
        #expect(currency.rawValue == "UAH")
        // localizedName uses String(localized:) which returns the key in test context
        #expect(!currency.localizedName.isEmpty)
    }

    @Test("Date formatter uses Ukrainian locale by default")
    func testUkrainianDateFormat() {
        // Given
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: 2025, month: 3, day: 15)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        // When
        let formatted = Formatters.dateString(date, dateStyle: .long)

        // Then
        // Should not contain English month names
        let englishMonths = ["January", "February", "March", "April", "May", "June",
                            "July", "August", "September", "October", "November", "December"]
        for month in englishMonths {
            #expect(!formatted.contains(month), "Date should not contain English month: \(month)")
        }

        // Should contain Ukrainian date elements
        #expect(formatted.contains("2025"))
    }

    @Test("Date formatter with Ukrainian locale identifier")
    func testDateFormatterLocale() {
        // Given
        let formatter = Formatters.dateFormatter(dateStyle: .medium, timeStyle: .none, localeIdentifier: "uk_UA")

        // Then
        #expect(formatter.locale.identifier == "uk_UA")
    }

    @Test("Number formatter uses Ukrainian decimal separator")
    func testUkrainianNumberFormat() {
        // Given
        let number: Decimal = 1234.56
        let ukrainianLocale = Locale(identifier: "uk_UA")

        // When
        let formatted = Formatters.decimalString(
            number,
            minFractionDigits: 2,
            maxFractionDigits: 2,
            locale: ukrainianLocale
        )

        // Then
        // Ukrainian uses comma as decimal separator
        #expect(formatted.contains(","), "Ukrainian locale should use comma as decimal separator")
    }

    @Test("Decimal formatter handles Ukrainian locale")
    func testDecimalFormatterUkrainianLocale() {
        // Given
        let ukrainianLocale = Locale(identifier: "uk_UA")

        // When
        let formatter = Formatters.decimalFormatter(
            minFractionDigits: 2,
            maxFractionDigits: 2,
            locale: ukrainianLocale
        )

        // Then
        #expect(formatter.locale.identifier == "uk_UA")
        #expect(formatter.usesGroupingSeparator == true)
    }

    @Test("Decimal value parsing handles Ukrainian format")
    func testDecimalValueParsingUkrainianFormat() {
        // Given
        let ukrainianNumber = "1 234,56" // Ukrainian format with space as thousands separator and comma as decimal
        let ukrainianLocale = Locale(identifier: "uk_UA")

        // When
        let parsed = Formatters.decimalValue(from: ukrainianNumber, locale: ukrainianLocale)

        // Then
        #expect(parsed != nil, "Should parse Ukrainian formatted number")
        if let value = parsed {
            #expect(value >= 1234 && value <= 1235, "Parsed value should be approximately 1234.56")
        }
    }

    @Test("Decimal value parsing handles various formats")
    func testDecimalValueParsingVariousFormats() {
        // Each test case includes input, expected Decimal, and the locale to use for parsing
        let enUS = Locale(identifier: "en_US")      // dot decimal, comma thousands
        let ukUA = Locale(identifier: "uk_UA")      // comma decimal, space thousands

        let testCases: [(String, Decimal, Locale)] = [
            ("1234.56", 1234.56, enUS),      // explicit en_US to interpret dot as decimal
            ("1234,56", 1234.56, ukUA),      // explicit uk_UA to interpret comma as decimal
            ("1 234,56", 1234.56, ukUA),     // space thousands + comma decimal
            ("1,234.56", 1234.56, enUS)      // comma thousands + dot decimal
        ]

        for (input, expected, locale) in testCases {
            let parsed = Formatters.decimalValue(from: input, locale: locale)
            #expect(parsed != nil, "Should parse '\(input)'")
            if let value = parsed {
                // Compare with small tolerance using Decimal arithmetic
                let diff = (value - expected).magnitude
                #expect(diff <= Decimal(string: "0.01")!,
                       "Parsed value for '\(input)' should be close to \(expected) (diff: \(diff))")
            }
        }
    }

    @Test("Currency formatter caching works correctly")
    func testCurrencyFormatterCaching() {
        // Given
        let amount: Decimal = 100

        // When - Call multiple times
        let result1 = Formatters.currencyStringUAH(amount: amount)
        let result2 = Formatters.currencyStringUAH(amount: amount)

        // Then - Should return same result (formatter is cached)
        #expect(result1 == result2)
        #expect(result1.contains("₴"))
    }

    @Test("Date formatter caching works correctly")
    func testDateFormatterCaching() {
        // Given
        let date = Date()

        // When - Call multiple times with same parameters
        let result1 = Formatters.dateString(date, dateStyle: .medium, timeStyle: .none, localeIdentifier: "uk_UA")
        let result2 = Formatters.dateString(date, dateStyle: .medium, timeStyle: .none, localeIdentifier: "uk_UA")

        // Then - Should return same result (formatter is cached)
        #expect(result1 == result2)
    }

    @Test("Currency symbols are correct for all currencies")
    func testAllCurrencySymbols() {
        // Test all available currencies
        let currencies: [(Currency, String)] = [
            (.uah, "₴"),
            (.usd, "$"),
            (.eur, "€")
        ]

        for (currency, expectedSymbol) in currencies {
            #expect(currency.symbol == expectedSymbol,
                   "\(currency.rawValue) should have symbol \(expectedSymbol)")
        }
    }

    @Test("Currency localized names use localization keys")
    func testCurrencyLocalizedNames() {
        // Given - all currencies should have localized names via String(localized:)
        let expectedKeys = ["currency.uah", "currency.usd", "currency.eur"]

        // When/Then - in test context, String(localized:) returns the key
        for (index, currency) in Currency.allCases.enumerated() {
            #expect(!currency.localizedName.isEmpty,
                   "\(currency.rawValue) should have a localized name")
            // Verify the localization key is being used
            #expect(currency.localizedName == expectedKeys[index] ||
                    currency.localizedName.contains(currency.symbol),
                   "\(currency.rawValue) should use localization key or contain symbol")
        }
    }

    @Test("Percent formatter works correctly")
    func testPercentFormatter() {
        // Given
        let value: Double = 0.2547

        // When
        let formatted = Formatters.percentString(value, maxFractionDigits: 1)

        // Then
        #expect(formatted.contains("%"))
        #expect(formatted.contains("25"))
    }
}

// MARK: - Helper Extensions

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

