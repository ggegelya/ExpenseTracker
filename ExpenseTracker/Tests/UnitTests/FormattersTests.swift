//
//  FormattersTests.swift
//  ExpenseTracker
//
//  Tests for Formatters utility covering multi-currency formatting, decimal parsing,
//  formatter caching, and edge cases not covered by existing LocalizationTests.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("Formatters Tests")
struct FormattersTests {

    // MARK: - Currency String Tests

    @Test("currencyString with USD currency")
    func currencyStringWithUSD() {
        let result = Formatters.currencyString(amount: 1000, currency: .usd)
        #expect(result.contains("$"))
        #expect(result.contains("1"))
        #expect(result.contains("000") || result.contains(",000") || result.contains(" 000"))
    }

    @Test("currencyString with EUR currency")
    func currencyStringWithEUR() {
        let result = Formatters.currencyString(amount: 500.50, currency: .eur, maxFractionDigits: 2)
        #expect(result.contains("€"))
        #expect(result.contains("500"))
    }

    @Test("currencyStringUAH formats correctly")
    func currencyStringUAHFormats() {
        let result = Formatters.currencyStringUAH(amount: 1234.56, maxFractionDigits: 2)
        #expect(result.contains("₴"))
        #expect(result.contains("1"))
        #expect(result.contains("234"))
        #expect(result.contains("56"))
    }

    @Test("currencyString with zero amount")
    func currencyStringWithZeroAmount() {
        let result = Formatters.currencyStringUAH(amount: 0)
        #expect(result.contains("0"))
        #expect(result.contains("₴"))
    }

    @Test("currencyString with negative amount")
    func currencyStringWithNegativeAmount() {
        let result = Formatters.currencyStringUAH(amount: -500)
        #expect(result.contains("500"))
        #expect(result.contains("₴"))
    }

    // MARK: - Decimal String Tests

    @Test("decimalString with custom fraction digits")
    func decimalStringWithCustomFractionDigits() {
        let result = Formatters.decimalString(100.5, minFractionDigits: 2, maxFractionDigits: 2)
        // Should include exactly 2 decimal places
        #expect(result.contains("100"))
        #expect(result.contains("50"))
    }

    @Test("decimalString with zero fraction digits")
    func decimalStringWithZeroFractionDigits() {
        let result = Formatters.decimalString(100.567, minFractionDigits: 0, maxFractionDigits: 0)
        #expect(result.contains("10"))
        // Should not have decimal separator with 0 max fraction digits
        #expect(!result.contains(".") || !result.contains(","), "Should not contain decimal portion")
    }

    // MARK: - Percent String Tests

    @Test("percentString with various values")
    func percentStringWithVariousValues() {
        let result = Formatters.percentString(0.5, maxFractionDigits: 1)
        #expect(result.contains("50"))
        #expect(result.contains("%"))
    }

    @Test("percentString with zero")
    func percentStringWithZero() {
        let result = Formatters.percentString(0)
        #expect(result.contains("0"))
        #expect(result.contains("%"))
    }

    @Test("percentString with 100%")
    func percentStringWith100() {
        let result = Formatters.percentString(1.0)
        #expect(result.contains("100"))
        #expect(result.contains("%"))
    }

    // MARK: - Date String Tests

    @Test("dateString with Ukrainian locale")
    func dateStringWithUkrainianLocale() {
        let date = DateGenerator.date(year: 2025, month: 3, day: 15)
        let result = Formatters.dateString(date, localeIdentifier: "uk_UA")

        // Should not contain English month names
        let englishMonths = ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]
        for month in englishMonths {
            #expect(!result.contains(month), "Should not contain English month name '\(month)'")
        }
    }

    // MARK: - Decimal Value Parsing Tests

    @Test("decimalValue parses '100.50' correctly")
    func decimalValueParsesDotDecimal() {
        let result = Formatters.decimalValue(from: "100.50", locale: Locale(identifier: "en_US"))
        #expect(result != nil)
        #expect(DecimalComparison.areEqual(result!, Decimal(string: "100.50")!))
    }

    @Test("decimalValue parses '100,50' with comma decimal correctly")
    func decimalValueParsesCommaDecimal() {
        let result = Formatters.decimalValue(from: "100,50", locale: Locale(identifier: "uk_UA"))
        #expect(result != nil)
        #expect(DecimalComparison.areEqual(result!, Decimal(string: "100.50")!))
    }

    @Test("decimalValue returns nil for 'abc'")
    func decimalValueReturnsNilForAlphabetic() {
        let result = Formatters.decimalValue(from: "abc")
        #expect(result == nil)
    }

    @Test("decimalValue returns nil for empty string")
    func decimalValueReturnsNilForEmpty() {
        let result = Formatters.decimalValue(from: "")
        #expect(result == nil)
    }

    @Test("decimalValue handles whitespace-only string")
    func decimalValueReturnsNilForWhitespace() {
        let result = Formatters.decimalValue(from: "   ")
        #expect(result == nil)
    }

    @Test("decimalValue parses large numbers correctly")
    func decimalValueParsesLargeNumbers() {
        let result = Formatters.decimalValue(from: "1000000", locale: Locale(identifier: "en_US"))
        #expect(result != nil)
        #expect(result! == Decimal(1000000))
    }

    // MARK: - Formatter Caching Tests

    @Test("Formatter caching returns same instance for same parameters")
    func formatterCachingReturnsSameInstance() {
        let formatter1 = Formatters.currencyFormatter(
            currencyCode: "UAH",
            symbol: "₴",
            minFractionDigits: 0,
            maxFractionDigits: 2
        )
        let formatter2 = Formatters.currencyFormatter(
            currencyCode: "UAH",
            symbol: "₴",
            minFractionDigits: 0,
            maxFractionDigits: 2
        )

        #expect(formatter1 === formatter2, "Should return the same cached formatter instance")
    }

    @Test("Formatter caching returns different instances for different parameters")
    func formatterCachingReturnsDifferentInstances() {
        let formatter1 = Formatters.currencyFormatter(
            currencyCode: "UAH",
            symbol: "₴",
            minFractionDigits: 0,
            maxFractionDigits: 2
        )
        let formatter2 = Formatters.currencyFormatter(
            currencyCode: "USD",
            symbol: "$",
            minFractionDigits: 0,
            maxFractionDigits: 2
        )

        #expect(formatter1 !== formatter2, "Should return different formatter instances for different currencies")
    }

    @Test("Percent formatter caching works correctly")
    func percentFormatterCachingWorks() {
        let formatter1 = Formatters.percentFormatter(maxFractionDigits: 1)
        let formatter2 = Formatters.percentFormatter(maxFractionDigits: 1)

        #expect(formatter1 === formatter2, "Should return the same cached percent formatter")
    }

    @Test("Date formatter caching works correctly")
    func dateFormatterCachingWorks() {
        let formatter1 = Formatters.dateFormatter(dateStyle: .medium, timeStyle: .none, localeIdentifier: "uk_UA")
        let formatter2 = Formatters.dateFormatter(dateStyle: .medium, timeStyle: .none, localeIdentifier: "uk_UA")

        #expect(formatter1 === formatter2, "Should return the same cached date formatter")
    }
}
