//
//  MockData.swift
//  ExpenseTracker
//
//  Factory methods for creating test data fixtures
//

import Foundation

// MARK: - Mock Account Factory

/// Provides factory methods for creating test Account instances
enum MockAccount {
    /// Creates a default cash account with UAH currency
    static func makeDefault() -> Account {
        Account(
            id: UUID(),
            name: "Готівка",
            tag: "#готівка",
            balance: 5000.00,
            isDefault: true,
            accountType: .cash,
            currency: .uah,
            lastTransactionDate: DateGenerator.today()
        )
    }

    /// Creates a secondary card account
    static func makeSecondary() -> Account {
        Account(
            id: UUID(),
            name: "Картка ПриватБанк",
            tag: "#приват",
            balance: 10000.00,
            isDefault: false,
            accountType: .card,
            currency: .uah,
            lastTransactionDate: DateGenerator.yesterday()
        )
    }

    /// Creates a USD savings account
    static func makeSavings() -> Account {
        Account(
            id: UUID(),
            name: "Заощадження",
            tag: "#savings",
            balance: 2000.00,
            isDefault: false,
            accountType: .savings,
            currency: .usd,
            lastTransactionDate: DateGenerator.daysAgo(7)
        )
    }

    /// Creates an investment account with EUR currency
    static func makeInvestment() -> Account {
        Account(
            id: UUID(),
            name: "Інвестиції",
            tag: "#invest",
            balance: 5000.00,
            isDefault: false,
            accountType: .investment,
            currency: .eur,
            lastTransactionDate: DateGenerator.daysAgo(30)
        )
    }

    /// Creates a banking-connected account (with bank metadata)
    static func makeBankConnected() -> Account {
        Account(
            id: UUID(),
            name: "Mono",
            tag: "#mono",
            balance: 15000.00,
            isDefault: false,
            accountType: .card,
            currency: .uah,
            lastTransactionDate: DateGenerator.now()
        )
    }

    /// Creates an account with custom parameters
    /// - Parameters:
    ///   - name: Account name
    ///   - tag: Account tag (must start with #)
    ///   - balance: Account balance
    ///   - isDefault: Whether this is the default account
    ///   - type: Account type
    ///   - currency: Currency type
    /// - Returns: Configured account
    static func makeCustom(
        name: String = "Test Account",
        tag: String = "#test",
        balance: Decimal = 1000.00,
        isDefault: Bool = false,
        type: AccountType = .cash,
        currency: Currency = .uah
    ) -> Account {
        Account(
            id: UUID(),
            name: name,
            tag: tag,
            balance: balance,
            isDefault: isDefault,
            accountType: type,
            currency: currency,
            lastTransactionDate: DateGenerator.today()
        )
    }

    /// Creates an empty account with zero balance
    static func makeEmpty() -> Account {
        Account(
            id: UUID(),
            name: "Пуста Картка",
            tag: "#empty",
            balance: 0.00,
            isDefault: false,
            accountType: .card,
            currency: .uah,
            lastTransactionDate: nil
        )
    }

    /// Creates multiple accounts for testing
    /// - Parameter count: Number of accounts to create (defaults to 3)
    /// - Returns: Array of accounts
    static func makeMultiple(count: Int = 3) -> [Account] {
        var accounts = [makeDefault(), makeSecondary(), makeSavings()]

        // Add more if needed
        while accounts.count < count {
            accounts.append(makeCustom(
                name: "Account \(accounts.count + 1)",
                tag: "#acc\(accounts.count + 1)",
                balance: Decimal(Double.random(in: 1000...10000))
            ))
        }

        return Array(accounts.prefix(count))
    }
}

// MARK: - Mock Category Factory

/// Provides factory methods for creating test Category instances
enum MockCategory {
    /// Returns all default Ukrainian categories
    static func makeDefaultCategories() -> [Category] {
        return [
            Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50"),
            Category(id: UUID(), name: "таксі", icon: "car.fill", colorHex: "#FFC107"),
            Category(id: UUID(), name: "підписки", icon: "repeat", colorHex: "#9C27B0"),
            Category(id: UUID(), name: "комуналка", icon: "house.fill", colorHex: "#2196F3"),
            Category(id: UUID(), name: "аптека", icon: "cross.case.fill", colorHex: "#F44336"),
            Category(id: UUID(), name: "транспорт", icon: "bus.fill", colorHex: "#2196F3"),
            Category(id: UUID(), name: "кафе", icon: "cup.and.saucer.fill", colorHex: "#FF9800"),
            Category(id: UUID(), name: "розваги", icon: "ticket.fill", colorHex: "#E91E63"),
            Category(id: UUID(), name: "одяг", icon: "tshirt.fill", colorHex: "#9C27B0"),
            Category(id: UUID(), name: "подарунки", icon: "gift.fill", colorHex: "#FF5722"),
            Category(id: UUID(), name: "навчання", icon: "book.fill", colorHex: "#3F51B5"),
            Category(id: UUID(), name: "спорт", icon: "figure.run", colorHex: "#4CAF50"),
            Category(id: UUID(), name: "краса", icon: "sparkles", colorHex: "#E91E63"),
            Category(id: UUID(), name: "техніка", icon: "desktopcomputer", colorHex: "#607D8B"),
            Category(id: UUID(), name: "інше", icon: "ellipsis.circle.fill", colorHex: "#9E9E9E")
        ]
    }

    /// Creates a groceries category
    static func makeGroceries() -> Category {
        Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50")
    }

    /// Creates a taxi category
    static func makeTaxi() -> Category {
        Category(id: UUID(), name: "таксі", icon: "car.fill", colorHex: "#FFC107")
    }

    /// Creates a transport category
    static func makeTransport() -> Category {
        Category(id: UUID(), name: "транспорт", icon: "bus.fill", colorHex: "#2196F3")
    }

    /// Creates a cafe category
    static func makeCafe() -> Category {
        Category(id: UUID(), name: "кафе", icon: "cup.and.saucer.fill", colorHex: "#FF9800")
    }

    /// Creates an entertainment category
    static func makeEntertainment() -> Category {
        Category(id: UUID(), name: "розваги", icon: "ticket.fill", colorHex: "#E91E63")
    }

    /// Creates a health category
    static func makeHealth() -> Category {
        Category(id: UUID(), name: "здоров'я", icon: "heart.fill", colorHex: "#F44336")
    }

    /// Creates a salary category (income)
    static func makeSalary() -> Category {
        Category(id: UUID(), name: "зарплата", icon: "dollarsign.circle.fill", colorHex: "#4CAF50")
    }

    /// Creates a utilities category
    static func makeUtilities() -> Category {
        Category(id: UUID(), name: "комуналка", icon: "house.fill", colorHex: "#2196F3")
    }

    /// Creates a custom category
    /// - Parameters:
    ///   - name: Category name
    ///   - icon: SF Symbol icon name
    ///   - colorHex: Hex color code
    /// - Returns: Configured category
    static func makeCustom(
        name: String = "Test Category",
        icon: String = "tag.fill",
        colorHex: String = "#9E9E9E"
    ) -> Category {
        Category(id: UUID(), name: name, icon: icon, colorHex: colorHex)
    }

    /// Creates a random category from defaults
    static func makeRandom() -> Category {
        makeDefaultCategories().randomElement()!
    }
}

// MARK: - Mock Transaction Factory

/// Provides factory methods for creating test Transaction instances
enum MockTransaction {
    /// Creates a basic expense transaction
    static func makeExpense(
        amount: Decimal = 250.00,
        category: Category? = nil,
        account: Account? = nil,
        description: String = "Test Expense",
        date: Date = DateGenerator.today(),
        merchantName: String? = nil
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .expense,
            amount: amount,
            category: category ?? MockCategory.makeGroceries(),
            description: description,
            merchantName: merchantName,
            fromAccount: account ?? MockAccount.makeDefault(),
            toAccount: nil,
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates a basic income transaction
    static func makeIncome(
        amount: Decimal = 5000.00,
        category: Category? = nil,
        account: Account? = nil,
        description: String = "Зарплата",
        date: Date = DateGenerator.today(),
        merchantName: String? = nil
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .income,
            amount: amount,
            category: category ?? MockCategory.makeSalary(),
            description: description,
            merchantName: merchantName,
            fromAccount: nil,
            toAccount: account ?? MockAccount.makeDefault(),
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates a transfer transaction between two accounts
    static func makeTransfer(
        amount: Decimal = 1000.00,
        fromAccount: Account? = nil,
        toAccount: Account? = nil,
        date: Date = DateGenerator.today(),
        merchantName: String? = nil
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .transferOut,
            amount: amount,
            category: nil,
            description: "Переказ",
            merchantName: merchantName,
            fromAccount: fromAccount ?? MockAccount.makeDefault(),
            toAccount: toAccount ?? MockAccount.makeSecondary(),
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates a split transaction with multiple categories
    static func makeSplit(
        totalAmount: Decimal = 500.00,
        account: Account? = nil,
        date: Date = DateGenerator.today()
    ) -> Transaction {
        let parentId = UUID()
        let account = account ?? MockAccount.makeDefault()

        let splitTransactions = [
            Transaction(
                id: UUID(),
                timestamp: date,
                transactionDate: date,
                type: .expense,
                amount: 300.00,
                category: MockCategory.makeGroceries(),
                description: "Продукти",
                fromAccount: account,
                toAccount: nil,
                parentTransactionId: parentId,
                splitTransactions: nil
            ),
            Transaction(
                id: UUID(),
                timestamp: date,
                transactionDate: date,
                type: .expense,
                amount: 200.00,
                category: MockCategory.makeHealth(),
                description: "Аптека",
                fromAccount: account,
                toAccount: nil,
                parentTransactionId: parentId,
                splitTransactions: nil
            )
        ]

        return Transaction(
            id: parentId,
            timestamp: date,
            transactionDate: date,
            type: .expense,
            amount: totalAmount,
            category: nil,
            description: "Split Transaction",
            fromAccount: account,
            toAccount: nil,
            parentTransactionId: nil,
            splitTransactions: splitTransactions
        )
    }

    /// Creates a groceries expense at Silpo
    static func makeGroceriesAtSilpo(
        amount: Decimal = 350.00,
        date: Date = DateGenerator.today()
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .expense,
            amount: amount,
            category: MockCategory.makeGroceries(),
            description: "Silpo - продукти",
            fromAccount: MockAccount.makeDefault(),
            toAccount: nil,
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates an Uber taxi expense
    static func makeUberRide(
        amount: Decimal = 120.00,
        date: Date = DateGenerator.today()
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .expense,
            amount: amount,
            category: MockCategory.makeTaxi(),
            description: "Uber",
            fromAccount: MockAccount.makeDefault(),
            toAccount: nil,
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates a Netflix subscription expense
    static func makeNetflixSubscription(
        amount: Decimal = 199.00,
        date: Date = DateGenerator.today()
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .expense,
            amount: amount,
            category: MockCategory.makeEntertainment(),
            description: "Netflix subscription",
            fromAccount: MockAccount.makeDefault(),
            toAccount: nil,
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates a salary income transaction
    static func makeSalaryPayment(
        amount: Decimal = 25000.00,
        date: Date = DateGenerator.today()
    ) -> Transaction {
        Transaction(
            id: UUID(),
            timestamp: date,
            transactionDate: date,
            type: .income,
            amount: amount,
            category: MockCategory.makeSalary(),
            description: "Зарплата за місяць",
            fromAccount: nil,
            toAccount: MockAccount.makeDefault(),
            parentTransactionId: nil,
            splitTransactions: nil
        )
    }

    /// Creates multiple transactions for testing
    /// - Parameters:
    ///   - count: Number of transactions to create
    ///   - dateRange: Number of days to spread transactions across
    /// - Returns: Array of transactions
    static func makeMultiple(count: Int = 10, dateRange: Int = 30) -> [Transaction] {
        var transactions: [Transaction] = []
        let account = MockAccount.makeDefault()

        for _ in 0..<count {
            let date = DateGenerator.randomDate(withinLast: dateRange)
            let isExpense = Bool.random()

            if isExpense {
                let amount = RandomDataGenerator.randomAmount(min: 50, max: 500)
                let category = MockCategory.makeRandom()
                transactions.append(makeExpense(
                    amount: amount,
                    category: category,
                    account: account,
                    description: RandomDataGenerator.randomDescription(),
                    date: date
                ))
            } else {
                let amount = RandomDataGenerator.randomAmount(min: 1000, max: 10000)
                transactions.append(makeIncome(
                    amount: amount,
                    account: account,
                    description: "Дохід \(transactions.count + 1)",
                    date: date
                ))
            }
        }

        return transactions.sorted { $0.transactionDate > $1.transactionDate }
    }

    /// Creates transactions for the current month
    static func makeForCurrentMonth(count: Int = 15) -> [Transaction] {
        var transactions: [Transaction] = []
        let account = MockAccount.makeDefault()
        let startDate = DateGenerator.startOfMonth()
        let endDate = DateGenerator.endOfMonth()
        let dayRange = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 30

        for _ in 0..<count {
            let randomDay = Int.random(in: 0...dayRange)
            let date = Calendar.current.date(byAdding: .day, value: randomDay, to: startDate)!

            let transaction = makeExpense(
                amount: RandomDataGenerator.randomAmount(min: 50, max: 1000),
                category: MockCategory.makeRandom(),
                account: account,
                description: RandomDataGenerator.randomDescription(),
                date: date
            )
            transactions.append(transaction)
        }

        return transactions.sorted { $0.transactionDate > $1.transactionDate }
    }
}

// MARK: - Mock Pending Transaction Factory

/// Provides factory methods for creating test PendingTransaction instances
enum MockPendingTransaction {
    /// Creates a basic pending transaction
    static func makePending(
        amount: Decimal = 250.00,
        description: String = "Pending Transaction",
        merchantName: String? = "Silpo",
        account: Account? = nil,
        suggestedCategory: Category? = nil,
        confidence: Float = 0.85,
        date: Date = DateGenerator.today()
    ) -> PendingTransaction {
        PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_\(UUID().uuidString.prefix(8))",
            amount: amount,
            descriptionText: description,
            merchantName: merchantName,
            transactionDate: date,
            type: .expense,
            account: account ?? MockAccount.makeDefault(),
            suggestedCategory: suggestedCategory ?? MockCategory.makeGroceries(),
            confidence: confidence,
            importedAt: DateGenerator.now(),
            status: .pending
        )
    }

    /// Creates a pending Silpo transaction with high confidence
    static func makePendingSilpo(
        amount: Decimal = 350.00,
        date: Date = DateGenerator.yesterday()
    ) -> PendingTransaction {
        PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_SILPO_\(UUID().uuidString.prefix(8))",
            amount: amount,
            descriptionText: "Silpo супермаркет",
            merchantName: "Silpo",
            transactionDate: date,
            type: .expense,
            account: MockAccount.makeBankConnected(),
            suggestedCategory: MockCategory.makeGroceries(),
            confidence: 0.95,
            importedAt: DateGenerator.now(),
            status: .pending
        )
    }

    /// Creates a pending Uber transaction
    static func makePendingUber(
        amount: Decimal = 150.00,
        date: Date = DateGenerator.today()
    ) -> PendingTransaction {
        PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_UBER_\(UUID().uuidString.prefix(8))",
            amount: amount,
            descriptionText: "Uber поїздка",
            merchantName: "Uber",
            transactionDate: date,
            type: .expense,
            account: MockAccount.makeBankConnected(),
            suggestedCategory: MockCategory.makeTaxi(),
            confidence: 0.90,
            importedAt: DateGenerator.now(),
            status: .pending
        )
    }

    /// Creates a pending transaction with low confidence (needs review)
    static func makePendingLowConfidence(
        amount: Decimal = 200.00,
        date: Date = DateGenerator.today()
    ) -> PendingTransaction {
        PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_UNKNOWN_\(UUID().uuidString.prefix(8))",
            amount: amount,
            descriptionText: "Незнайомий продавець",
            merchantName: nil,
            transactionDate: date,
            type: .expense,
            account: MockAccount.makeBankConnected(),
            suggestedCategory: nil,
            confidence: 0.30,
            importedAt: DateGenerator.now(),
            status: .pending
        )
    }

    /// Creates multiple pending transactions
    static func makeMultiple(count: Int = 5) -> [PendingTransaction] {
        var transactions: [PendingTransaction] = []

        for index in 0..<count {
            let amount = RandomDataGenerator.randomAmount(min: 50, max: 500)
            let date = DateGenerator.randomDate(withinLast: 7)
            let merchantName = Bool.random() ? RandomDataGenerator.randomMerchantName() : nil
            let confidence = Float.random(in: 0.3...0.95)

            transactions.append(makePending(
                amount: amount,
                description: "Pending \(index + 1)",
                merchantName: merchantName,
                confidence: confidence,
                date: date
            ))
        }

        return transactions
    }

    /// Creates a processed pending transaction
    static func makeProcessed(
        amount: Decimal = 250.00,
        date: Date = DateGenerator.yesterday()
    ) -> PendingTransaction {
        PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_PROCESSED_\(UUID().uuidString.prefix(8))",
            amount: amount,
            descriptionText: "Processed Transaction",
            merchantName: "Silpo",
            transactionDate: date,
            type: .expense,
            account: MockAccount.makeBankConnected(),
            suggestedCategory: MockCategory.makeGroceries(),
            confidence: 0.85,
            importedAt: DateGenerator.daysAgo(2),
            status: .processed
        )
    }

    /// Creates a dismissed pending transaction
    static func makeDismissed(
        amount: Decimal = 100.00,
        date: Date = DateGenerator.daysAgo(3)
    ) -> PendingTransaction {
        PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_DISMISSED_\(UUID().uuidString.prefix(8))",
            amount: amount,
            descriptionText: "Dismissed Transaction",
            merchantName: nil,
            transactionDate: date,
            type: .expense,
            account: MockAccount.makeBankConnected(),
            suggestedCategory: nil,
            confidence: 0.50,
            importedAt: DateGenerator.daysAgo(4),
            status: .dismissed
        )
    }
}
