//
//  ModelTests.swift
//  ExpenseTracker
//
//  Tests for Account validation, AccountType, Currency, and TransactionType models.
//

import Testing
import Foundation
@testable import ExpenseTracker

// MARK: - Account Validation Tests

@Suite("Account Validation Tests")
struct AccountValidationTests {

    @Test("validate throws emptyName for empty name")
    func validateThrowsEmptyName() {
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: "", tag: "#test")
        }
    }

    @Test("validate throws emptyName for whitespace-only name")
    func validateThrowsEmptyNameForWhitespace() {
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: "   ", tag: "#test")
        }
    }

    @Test("validate throws nameTooLong for name over 50 characters")
    func validateThrowsNameTooLong() {
        let longName = String(repeating: "a", count: 51)
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: longName, tag: "#test")
        }
    }

    @Test("validate passes for valid name at 50 characters")
    func validatePassesForMaxLengthName() throws {
        let name = String(repeating: "a", count: 50)
        try Account.validate(name: name, tag: "#test")
    }

    @Test("validate throws emptyTag for empty tag")
    func validateThrowsEmptyTag() {
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: "Test Account", tag: "")
        }
    }

    @Test("validate throws emptyTag for whitespace-only tag")
    func validateThrowsEmptyTagForWhitespace() {
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: "Test Account", tag: "   ")
        }
    }

    @Test("validate throws invalidTagFormat for tag without # prefix")
    func validateThrowsInvalidTagFormat() {
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: "Test Account", tag: "notag")
        }
    }

    @Test("validate throws duplicateTag for existing tag")
    func validateThrowsDuplicateTag() {
        #expect(throws: Account.ValidationError.self) {
            try Account.validate(name: "Test", tag: "#existing", existingTags: ["#existing", "#other"])
        }
    }

    @Test("validate passes when tag does not duplicate existing tags")
    func validatePassesWhenTagIsUnique() throws {
        try Account.validate(name: "Test", tag: "#unique", existingTags: ["#other"])
    }

    @Test("validate passes for valid name and tag")
    func validatePassesForValidInput() throws {
        try Account.validate(name: "My Account", tag: "#main")
    }

    @Test("formattedBalance returns formatted string with currency")
    func formattedBalanceReturnsFormattedString() {
        let account = Account(name: "Test", tag: "#test", balance: 1500, currency: .uah)
        let formatted = account.formattedBalance()

        #expect(formatted.contains("1"))
        #expect(formatted.contains("500"))
        #expect(formatted.contains("₴"))
    }

    @Test("formattedBalance works with USD currency")
    func formattedBalanceWorksWithUSD() {
        let account = Account(name: "Test", tag: "#test", balance: 1000, currency: .usd)
        let formatted = account.formattedBalance()

        #expect(formatted.contains("$"))
    }

    @Test("formattedBalance works with EUR currency")
    func formattedBalanceWorksWithEUR() {
        let account = Account(name: "Test", tag: "#test", balance: 1000, currency: .eur)
        let formatted = account.formattedBalance()

        #expect(formatted.contains("€"))
    }

    @Test("ValidationError errorDescription returns non-empty for all cases")
    func validationErrorDescriptionReturnsNonEmpty() {
        let cases: [Account.ValidationError] = [
            .emptyName, .nameTooLong, .emptyTag, .invalidTagFormat, .duplicateTag
        ]

        for error in cases {
            #expect(error.errorDescription != nil, "errorDescription should not be nil for \(error)")
            #expect(!error.errorDescription!.isEmpty, "errorDescription should not be empty for \(error)")
        }
    }

    @Test("Account defaultAccount has correct properties")
    func defaultAccountHasCorrectProperties() {
        let account = Account.defaultAccount
        #expect(account.isDefault)
        #expect(account.accountType == .card)
        #expect(account.currency == .uah)
        #expect(account.balance == 0)
    }
}

// MARK: - AccountType Tests

@Suite("AccountType Tests")
struct AccountTypeTests {

    @Test("localizedName returns non-empty for all cases")
    func localizedNameReturnsNonEmpty() {
        for accountType in AccountType.allCases {
            #expect(!accountType.localizedName.isEmpty, "localizedName should not be empty for \(accountType)")
        }
    }

    @Test("icon returns valid SF Symbol name for all cases")
    func iconReturnsValidSFSymbol() {
        let expectedIcons: [AccountType: String] = [
            .cash: "banknote",
            .card: "creditcard",
            .savings: "doc.text.image",
            .investment: "chart.line.uptrend.xyaxis"
        ]

        for (accountType, expectedIcon) in expectedIcons {
            #expect(accountType.icon == expectedIcon)
        }
    }

    @Test("color returns correct color for all cases")
    func colorReturnsCorrectColor() {
        #expect(AccountType.cash.color == "green")
        #expect(AccountType.card.color == "blue")
        #expect(AccountType.savings.color == "orange")
        #expect(AccountType.investment.color == "purple")
    }

    @Test("CaseIterable contains all 4 types")
    func caseIterableContainsAll() {
        #expect(AccountType.allCases.count == 4)
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for accountType in AccountType.allCases {
            #expect(accountType.id == accountType.rawValue)
        }
    }
}

// MARK: - Currency Tests

@Suite("Currency Tests")
struct CurrencyTests {

    @Test("symbol returns correct symbols")
    func symbolReturnsCorrectSymbols() {
        #expect(Currency.uah.symbol == "₴")
        #expect(Currency.usd.symbol == "$")
        #expect(Currency.eur.symbol == "€")
    }

    @Test("rawValue returns correct currency codes")
    func rawValueReturnsCorrectCodes() {
        #expect(Currency.uah.rawValue == "UAH")
        #expect(Currency.usd.rawValue == "USD")
        #expect(Currency.eur.rawValue == "EUR")
    }

    @Test("localizedName returns non-empty for all cases")
    func localizedNameReturnsNonEmpty() {
        for currency in Currency.allCases {
            #expect(!currency.localizedName.isEmpty, "localizedName should not be empty for \(currency)")
        }
    }

    @Test("CaseIterable contains all 3 currencies")
    func caseIterableContainsAll() {
        #expect(Currency.allCases.count == 3)
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for currency in Currency.allCases {
            #expect(currency.id == currency.rawValue)
        }
    }
}

// MARK: - TransactionType Tests

@Suite("TransactionType Tests")
struct TransactionTypeTests {

    @Test("Custom init maps 'expense' correctly")
    func customInitMapsExpense() {
        #expect(TransactionType(rawValue: "expense") == .expense)
        #expect(TransactionType(rawValue: "Expense") == .expense)
        #expect(TransactionType(rawValue: "EXPENSE") == .expense)
    }

    @Test("Custom init maps 'income' correctly")
    func customInitMapsIncome() {
        #expect(TransactionType(rawValue: "income") == .income)
        #expect(TransactionType(rawValue: "Income") == .income)
    }

    @Test("Custom init maps 'transferout' and 'transfer-out' correctly")
    func customInitMapsTransferOut() {
        #expect(TransactionType(rawValue: "transferout") == .transferOut)
        #expect(TransactionType(rawValue: "TransferOut") == .transferOut)
        #expect(TransactionType(rawValue: "transfer-out") == .transferOut)
        #expect(TransactionType(rawValue: "Transfer-Out") == .transferOut)
    }

    @Test("Custom init maps 'transferin' and 'transfer-in' correctly")
    func customInitMapsTransferIn() {
        #expect(TransactionType(rawValue: "transferin") == .transferIn)
        #expect(TransactionType(rawValue: "TransferIn") == .transferIn)
        #expect(TransactionType(rawValue: "transfer-in") == .transferIn)
        #expect(TransactionType(rawValue: "Transfer-In") == .transferIn)
    }

    @Test("Custom init returns nil for invalid string")
    func customInitReturnsNilForInvalid() {
        #expect(TransactionType(rawValue: "invalid") == nil)
        #expect(TransactionType(rawValue: "") == nil)
        #expect(TransactionType(rawValue: "refund") == nil)
    }

    @Test("symbol returns '-' for expense and transferOut")
    func symbolReturnsMinusForExpenseAndTransferOut() {
        #expect(TransactionType.expense.symbol == "-")
        #expect(TransactionType.transferOut.symbol == "-")
    }

    @Test("symbol returns '+' for income and transferIn")
    func symbolReturnsPlusForIncomeAndTransferIn() {
        #expect(TransactionType.income.symbol == "+")
        #expect(TransactionType.transferIn.symbol == "+")
    }

    @Test("localizedName returns non-empty for all cases")
    func localizedNameReturnsNonEmpty() {
        for type in TransactionType.allCases {
            #expect(!type.localizedName.isEmpty, "localizedName should not be empty for \(type)")
        }
    }

    @Test("color returns 'red' for expense and transferOut")
    func colorReturnsRedForExpenseAndTransferOut() {
        #expect(TransactionType.expense.color == "red")
        #expect(TransactionType.transferOut.color == "red")
    }

    @Test("color returns 'green' for income and transferIn")
    func colorReturnsGreenForIncomeAndTransferIn() {
        #expect(TransactionType.income.color == "green")
        #expect(TransactionType.transferIn.color == "green")
    }

    @Test("CaseIterable has all 4 cases")
    func caseIterableHasAllCases() {
        #expect(TransactionType.allCases.count == 4)
        #expect(TransactionType.allCases.contains(.expense))
        #expect(TransactionType.allCases.contains(.income))
        #expect(TransactionType.allCases.contains(.transferOut))
        #expect(TransactionType.allCases.contains(.transferIn))
    }
}

// MARK: - Transaction Model Tests

@Suite("Transaction Model Tests")
struct TransactionModelTests {

    @Test("isSplitParent returns true when splitTransactions is non-empty")
    func isSplitParentReturnsTrueForNonEmpty() {
        let child = Transaction(type: .expense, amount: 100, description: "Child")
        let parent = Transaction(
            type: .expense,
            amount: 500,
            description: "Parent",
            splitTransactions: [child]
        )

        #expect(parent.isSplitParent)
    }

    @Test("isSplitParent returns false when splitTransactions is nil")
    func isSplitParentReturnsFalseForNil() {
        let transaction = Transaction(type: .expense, amount: 100, description: "Regular")
        #expect(!transaction.isSplitParent)
    }

    @Test("isSplitChild returns true when parentTransactionId is set")
    func isSplitChildReturnsTrueForParentId() {
        let child = Transaction(
            type: .expense,
            amount: 100,
            description: "Child",
            parentTransactionId: UUID()
        )
        #expect(child.isSplitChild)
    }

    @Test("effectiveAmount sums split children for parent")
    func effectiveAmountSumsSplitChildren() {
        let child1 = Transaction(type: .expense, amount: 300, description: "Part 1")
        let child2 = Transaction(type: .expense, amount: 200, description: "Part 2")
        let parent = Transaction(
            type: .expense,
            amount: 500,
            description: "Parent",
            splitTransactions: [child1, child2]
        )

        #expect(parent.effectiveAmount == Decimal(500))
    }

    @Test("effectiveAmount returns amount for regular transaction")
    func effectiveAmountReturnsAmountForRegular() {
        let transaction = Transaction(type: .expense, amount: 250, description: "Regular")
        #expect(transaction.effectiveAmount == Decimal(250))
    }

    @Test("primaryCategory returns largest split's category for parent")
    func primaryCategoryReturnsLargestSplitCategory() {
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()

        let child1 = Transaction(type: .expense, amount: 300, category: groceries, description: "Part 1")
        let child2 = Transaction(type: .expense, amount: 200, category: transport, description: "Part 2")
        let parent = Transaction(
            type: .expense,
            amount: 500,
            description: "Parent",
            splitTransactions: [child1, child2]
        )

        #expect(parent.primaryCategory?.id == groceries.id)
    }
}

// MARK: - Category Model Tests

@Suite("Category Model Tests")
struct CategoryModelTests {

    @Test("defaults contains expected number of categories")
    func defaultsContainsExpectedCount() {
        #expect(Category.defaults.count == 15)
    }

    @Test("defaults categories have non-empty names")
    func defaultsHaveNonEmptyNames() {
        for category in Category.defaults {
            #expect(!category.name.isEmpty)
        }
    }

    @Test("defaults categories have non-empty icons")
    func defaultsHaveNonEmptyIcons() {
        for category in Category.defaults {
            #expect(!category.icon.isEmpty)
        }
    }

    @Test("defaults categories have valid hex colors")
    func defaultsHaveValidHexColors() {
        for category in Category.defaults {
            #expect(category.colorHex.hasPrefix("#"))
        }
    }

    @Test("displayName returns name when localization key not found")
    func displayNameFallsBackToName() {
        let category = Category(id: UUID(), name: "test_nonexistent_key", icon: "tag.fill", colorHex: "#FF0000")
        // If the localization key doesn't match, displayName should return something non-empty
        #expect(!category.displayName.isEmpty)
    }
}

// MARK: - Account DisplayName Tests

@Suite("Account DisplayName Tests")
struct AccountDisplayNameTests {

    @Test("displayName falls back to raw name for unknown key")
    func displayNameFallsBackToRawName() {
        let account = Account(name: "my_custom_account", tag: "#custom")
        // "account.my_custom_account" has no localization → should fall back to raw name
        #expect(account.displayName == "my_custom_account")
    }

    @Test("displayName returns localized string for known key")
    func displayNameReturnsLocalizedForKnownKey() {
        let account = Account(name: "default_card", tag: "#main")
        // "account.default_card" is a known localization key
        // displayName should NOT equal the raw key "account.default_card"
        #expect(account.displayName != "account.default_card")
        // It should also be non-empty
        #expect(!account.displayName.isEmpty)
    }

    @Test("defaultAccount uses displayName correctly")
    func defaultAccountDisplayName() {
        let account = Account.defaultAccount
        // The default account name is "default_card"
        // displayName should resolve to something other than the key path
        #expect(account.displayName != "account.default_card")
        #expect(!account.displayName.isEmpty)
    }
}
