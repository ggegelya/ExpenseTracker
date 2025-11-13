# ExpenseTracker - Comprehensive Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Architecture](#architecture)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Data Models & Database](#data-models--database)
7. [Features](#features)
8. [Configuration & Deployment](#configuration--deployment)
9. [Testing](#testing)
10. [Development Guidelines](#development-guidelines)

---

## Project Overview

**ExpenseTracker** is a native iOS personal finance management application built with modern Swift and SwiftUI. The app provides comprehensive expense tracking, analytics, and account management with a focus on the Ukrainian market.

### Key Highlights
- **11,673 lines of Swift code** across 65 files
- **MVVM architecture** with dependency injection
- **Core Data + CloudKit** for local and cloud storage
- **Localized for Ukrainian language**
- **Production-ready** with comprehensive error handling and testing

---

## Technology Stack

### Core Technologies
- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI (declarative UI)
- **Database**: Core Data with NSPersistentCloudKitContainer
- **Cloud Sync**: CloudKit
- **Architecture**: MVVM (Model-View-ViewModel)
- **Dependency Injection**: Manual container pattern
- **Testing**: Swift Testing framework
- **Concurrency**: Swift Async/Await
- **Reactive Programming**: Combine framework

### Development Tools
- **IDE**: Xcode 14+
- **Build System**: Xcode Build System
- **Version Control**: Git
- **Deployment Target**: iOS 15+

---

## Architecture

### MVVM Pattern

```
┌─────────────┐
│    View     │ SwiftUI Views (declarative UI)
│  (SwiftUI)  │
└──────┬──────┘
       │ @EnvironmentObject / @StateObject
       ↓
┌─────────────┐
│  ViewModel  │ ObservableObject with @Published properties
│             │ Business logic & state management
└──────┬──────┘
       │ Protocol-based dependencies
       ↓
┌─────────────┐
│   Service   │ Business logic services
│ & Repository│ Data access abstraction
└──────┬──────┘
       │
       ↓
┌─────────────┐
│  Core Data  │ Persistence layer with CloudKit sync
└─────────────┘
```

### Dependency Injection

The app uses a centralized `DependencyContainer` (`ExpenseTracker/App/DependencyContainer.swift`) that:
- Initializes all services and repositories
- Manages environment-specific configurations
- Provides factory methods for ViewModels
- Supports testing with in-memory stores

```swift
class DependencyContainer {
    let persistenceController: PersistenceController
    let transactionRepository: TransactionRepositoryProtocol
    let categorizationService: CategorizationServiceProtocol
    let analyticsService: AnalyticsServiceProtocol

    @MainActor
    func makeTransactionViewModel() -> TransactionViewModel
}
```

---

## Project Structure

```
ExpenseTracker/
├── App/                              # Application configuration
│   ├── Configuration/
│   │   └── Environment.swift         # Environment setup (prod/staging/testing)
│   ├── DependencyContainer.swift     # DI container
│   ├── ExpenseTrackerApp.swift       # App entry point (@main)
│   └── MainTabView.swift             # Tab navigation
│
├── Core/                             # Core business logic
│   ├── ErrorHandling/                # Error management system
│   │   ├── AppError.swift
│   │   ├── ErrorSeverity.swift
│   │   ├── AlertMessage.swift
│   │   ├── ToastMessage.swift
│   │   └── Components/               # Error UI components
│   │
│   ├── Models/                       # Domain models
│   │   ├── Transaction.swift
│   │   ├── Account.swift
│   │   ├── Category.swift
│   │   ├── PendingTransaction.swift
│   │   └── TransactionType.swift
│   │
│   ├── Persistence/                  # Database layer
│   │   ├── Persistence.swift         # Core Data setup
│   │   └── ExpenseTracker.xcdatamodeld/
│   │
│   ├── Repository/                   # Data access layer
│   │   ├── Protocols/
│   │   │   └── TransactionRepositoryProtocol.swift
│   │   ├── Implementation/
│   │   │   └── CoreDataTransactionRepository.swift (760 LOC)
│   │   └── RepositoryError.swift
│   │
│   └── Services/                     # Business services
│       ├── AnalyticsService.swift
│       ├── CategorizationService.swift
│       ├── ExportService.swift
│       └── Banking/
│           └── BankingServiceProtocol.swift
│
├── Features/                         # Feature modules
│   ├── Transactions/                 # Transaction management
│   │   ├── TransactionListView.swift (419 LOC)
│   │   ├── TransactionViewModel.swift (827 LOC)
│   │   └── Components/
│   │       ├── TransactionRow.swift
│   │       ├── TransactionDetailView.swift
│   │       ├── SplitTransactionView.swift (535 LOC)
│   │       ├── SplitItemRow.swift
│   │       └── BulkActionsBar.swift
│   │
│   ├── QuickEntry/                   # Fast transaction entry
│   │   ├── QuickEntryView.swift (1,151 LOC - largest file)
│   │   └── Components/
│   │       ├── AmountInputSection.swift
│   │       └── CategoryChip.swift
│   │
│   ├── Analytics/                    # Financial analytics
│   │   ├── AnalyticsView.swift
│   │   ├── AnalyticsViewModel.swift (392 LOC)
│   │   └── Components/
│   │       ├── MonthOverviewCard.swift (291 LOC)
│   │       ├── CategoryBreakdownCard.swift
│   │       ├── TopMerchantsCard.swift
│   │       └── SpendingTrendsCard.swift
│   │
│   ├── Accounts/                     # Account management
│   │   ├── AccountsView.swift (230 LOC)
│   │   ├── AccountsViewModel.swift
│   │   └── Components/
│   │       ├── AddAccountView.swift (279 LOC)
│   │       ├── AccountDetailView.swift (266 LOC)
│   │       └── AccountRow.swift
│   │
│   └── PendingQueue/                 # Banking transaction queue
│       ├── PendingTransactionView.swift
│       ├── PendingTransactionViewModel.swift
│       └── Components/
│           ├── ProcessPendingView.swift (413 LOC)
│           ├── BatchProcessingView.swift (341 LOC)
│           ├── CategorySuggestionCard.swift (257 LOC)
│           └── PendingTransactionRow.swift
│
├── Shared/                           # Reusable components
│   ├── Views/                        # Shared UI components
│   │   ├── FilterView.swift (355 LOC)
│   │   ├── MonthSummaryCard.swift
│   │   ├── EmptyStateView.swift
│   │   └── LoadingView.swift
│   │
│   ├── Extensions/                   # Swift extensions
│   │   ├── View+Extensions.swift
│   │   ├── Decimal+Extensions.swift
│   │   └── Color+Hex.swift
│   │
│   └── Utilities/                    # Utility functions
│       └── Formatters.swift (295 LOC)
│
├── Tests/
│   ├── UnitTests/
│   │   ├── RepositoryTests.swift (435 LOC)
│   │   └── ExpenseTrackerTests.swift
│   └── UITests/
│       ├── ExpenseTrackerUITests.swift
│       └── ExpenseTrackerUITestsLaunchTests.swift
│
└── Resources/
    └── Assets.xcassets/              # App assets
```

---

## Core Components

### 1. Transaction Repository
**File**: `ExpenseTracker/Core/Repository/Implementation/CoreDataTransactionRepository.swift` (760 lines)

Provides abstraction over Core Data operations:
- CRUD operations for transactions, accounts, categories
- Filtering and searching capabilities
- Combine publishers for reactive data flow
- Batch operations for performance

**Key Methods**:
```swift
protocol TransactionRepositoryProtocol {
    // Transaction operations
    func createTransaction(_ transaction: Transaction) async throws -> Transaction
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction
    func deleteTransaction(id: UUID) async throws
    func getTransaction(id: UUID) async throws -> Transaction?
    func getAllTransactions() async throws -> [Transaction]

    // Publishers for reactive UI
    var transactionsPublisher: AnyPublisher<[Transaction], Error> { get }
    var accountsPublisher: AnyPublisher<[Account], Error> { get }
    var categoriesPublisher: AnyPublisher<[Category], Error> { get }
}
```

### 2. ViewModels

#### TransactionViewModel (827 lines)
**File**: `ExpenseTracker/Features/Transactions/TransactionViewModel.swift`

Manages transaction list and operations:
- Filtering by date, category, type, account, amount
- Bulk operations (edit, delete)
- Split transaction management
- Search functionality
- Quick entry state

**Key Properties**:
```swift
@Published var transactions: [Transaction] = []
@Published var selectedTransactions: Set<UUID> = []
@Published var filterType: TransactionType?
@Published var filterCategory: Category?
@Published var filterAccount: Account?
@Published var searchText: String = ""
```

#### AnalyticsViewModel (392 lines)
**File**: `ExpenseTracker/Features/Analytics/AnalyticsViewModel.swift`

Provides financial insights:
- Date range selection
- Category spending analysis
- Merchant analytics
- Month-over-month comparisons
- Spending trends

### 3. Categorization Service
**File**: `ExpenseTracker/Core/Services/CategorizationService.swift`

Provides intelligent transaction categorization:
- Merchant pattern matching (30+ Ukrainian merchants)
- Confidence scoring
- Learning from user corrections
- Auto-categorization rules

```swift
func suggestCategory(
    for description: String,
    merchantName: String?
) async -> (category: Category?, confidence: Float)
```

### 4. Error Handling System
**Location**: `ExpenseTracker/Core/ErrorHandling/`

Comprehensive error management:
- `AppError`: Categorized errors with localization
- `ErrorSeverity`: Critical, high, medium, low
- `AlertMessage`: Modal error display
- `ToastMessage`: Non-intrusive notifications
- Error UI components with retry capabilities

---

## Data Models & Database

### Core Data Schema

The app uses Core Data with CloudKit sync. Schema defined in `ExpenseTracker.xcdatamodeld`.

#### Entities

**1. TransactionEntity**
- **Attributes**: id, amount, type, transactionDate, timestamp, merchantName, bankTransactionId, isReconciled, notes, descriptionText
- **Relationships**:
  - `category` → CategoryEntity (many-to-one)
  - `fromAccount` → AccountEntity (many-to-one)
  - `toAccount` → AccountEntity (many-to-one)
  - `parentTransaction` → TransactionEntity (self-reference)
  - `splitTransactions` → [TransactionEntity] (one-to-many)

**2. AccountEntity**
- **Attributes**: id, name, tag, balance, currency, type, isDefault, bankAccountId, bankName, createdAt, lastSyncedAt
- **Relationships**:
  - `expenseTransactions` → [TransactionEntity]
  - `incomeTransactions` → [TransactionEntity]
  - `pendingTransactions` → [PendingTransactionEntity]

**3. CategoryEntity**
- **Attributes**: id, name, icon, colorHex, isSystem, monthlyBudget, sortOrder
- **Relationships**:
  - `transactions` → [TransactionEntity]
  - `rules` → [CategoryRuleEntity]

**4. PendingTransactionEntity**
- **Attributes**: id, amount, type, merchantName, bankTransactionId, descriptionText, transactionDate, importedAt, status, confidence, suggestedCategoryId
- **Relationships**: `account` → AccountEntity

**5. CategoryRuleEntity**
- **Attributes**: id, matchPattern, matchType, isActive, priority, createdAt
- **Relationships**: `category` → CategoryEntity

**6. MerchantEntity**
- **Attributes**: id, name, normalizedName, mcc, suggestedCategoryId, usageCount

### Swift Models

#### Transaction
```swift
struct Transaction: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let transactionDate: Date
    let type: TransactionType
    var amount: Decimal
    let category: Category?
    var description: String
    let fromAccount: Account?
    let toAccount: Account?
    var parentTransactionId: UUID?
    var splitTransactions: [Transaction]?

    var isSplitParent: Bool
    var effectiveAmount: Decimal
    var primaryCategory: Category?
}
```

#### Account
```swift
struct Account: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let tag: String
    var balance: Decimal
    var isDefault: Bool
    var accountType: AccountType
    var currency: Currency
    var lastTransactionDate: Date?
}
```

#### TransactionType
```swift
enum TransactionType: String, Codable {
    case expense
    case income
    case transferOut
    case transferIn
}
```

### Persistence Configuration

**File**: `ExpenseTracker/Core/Persistence/Persistence.swift`

```swift
NSPersistentCloudKitContainer(name: "ExpenseTracker")
```

**Features**:
- CloudKit sync for multi-device support
- History tracking enabled
- Automatic store migration
- Merge policy: NSMergeByPropertyObjectTrumpMergePolicy
- Batch loading with 50-item batches
- Prefetch relationships for performance

---

## Features

### 1. Quick Entry
**Main File**: `ExpenseTracker/Features/QuickEntry/QuickEntryView.swift` (1,151 lines)

Fast transaction entry interface:
- Type selection (Expense/Income)
- Amount input with currency formatting
- Category chip selection with visual feedback
- Auto-category suggestions
- Account selection
- Date picker
- Description with merchant auto-complete
- Pending transaction badge
- Success feedback with haptics

### 2. Transaction Management
**Main Files**:
- `TransactionListView.swift` (419 lines)
- `TransactionViewModel.swift` (827 lines)

Features:
- Transaction list grouped by date
- Advanced filtering:
  - Date range (custom picker)
  - Category
  - Type (expense/income/transfer)
  - Account
  - Amount range
  - Search text
- Bulk operations (edit, delete)
- Transaction details view
- Split transactions into multiple categories
- Edit/delete individual transactions

#### Split Transactions
**File**: `SplitTransactionView.swift` (535 lines)

Allows splitting a transaction across multiple categories:
- Add/remove split items
- Category selection per split
- Amount allocation
- Visual validation (total = transaction amount)
- Remaining amount indicator

### 3. Analytics
**Main Files**:
- `AnalyticsView.swift`
- `AnalyticsViewModel.swift` (392 lines)

Financial insights dashboard:

**Month Overview Card** (291 lines):
- Total income vs total expenses
- Net balance
- Month-over-month comparison
- Visual indicators (up/down trends)

**Category Breakdown**:
- Spending by category
- Percentage distribution
- Visual bars with category colors
- Top spending categories

**Top Merchants**:
- Spending by merchant
- Transaction count per merchant
- Amount totals

**Spending Trends**:
- Current month vs previous month
- Change percentages
- Trend visualization

**Date Range Selection**:
- Current month
- Last month
- Last 3 months
- Custom date range

### 4. Account Management
**Main Files**:
- `AccountsView.swift` (230 lines)
- `AddAccountView.swift` (279 lines)
- `AccountDetailView.swift` (266 lines)

Features:
- Multiple account support
- Account types: Cash, Card, Savings, Investment
- Balance tracking
- Default account setting
- Account tags for identification
- Account validation (name length, tag format)
- Visual cards with account type colors
- Horizontal scrollable account list

**Account Types**:
```swift
enum AccountType: String, Codable {
    case cash
    case card
    case savings
    case investment
}
```

**Supported Currencies**:
```swift
enum Currency: String, Codable {
    case UAH  // Ukrainian Hryvnia
    case USD  // US Dollar
    case EUR  // Euro
}
```

### 5. Pending Queue (Banking Integration)
**Main Files**:
- `PendingTransactionView.swift`
- `ProcessPendingView.swift` (413 lines)
- `BatchProcessingView.swift` (341 lines)

Features:
- Import transactions from banking APIs
- Category suggestions with confidence scores
- Batch processing of pending items
- Learning from user corrections
- Merchant pattern matching
- Status tracking (pending, processed, ignored)
- Polling mechanism (120-second intervals)
- Pause/resume monitoring

**Processing Flow**:
1. Banking API imports transactions
2. Categorization service suggests category + confidence
3. User reviews suggestions
4. User confirms or corrects category
5. System learns from corrections
6. Transaction moves from pending to processed

### 6. Export & Integration
**File**: `ExpenseTracker/Core/Services/ExportService.swift`

Features:
- CSV export with formatted data
- Google Sheets integration (placeholder)
- Date formatting with Ukrainian locale
- Currency formatting

**CSV Format**:
```
Date,Description,Category,Amount,Type,Account
2025-01-15,Grocery shopping,Продукти,250.00,Expense,Card
```

---

## Configuration & Deployment

### Environment Configuration
**File**: `ExpenseTracker/App/Configuration/Environment.swift`

```swift
enum AppEnvironment {
    case production   // Production with persistent store
    case staging      // Staging with persistent store
    case testing      // Testing with in-memory store
    case preview      // SwiftUI previews with in-memory store

    var usesInMemoryStore: Bool {
        switch self {
        case .testing, .preview: return true
        case .production, .staging: return false
        }
    }
}
```

### App Entry Point
**File**: `ExpenseTracker/App/ExpenseTrackerApp.swift`

```swift
@main
struct ExpenseTrackerApp: App {
    @StateObject private var container: DependencyContainer

    init() {
        #if DEBUG
        let environment: AppEnvironment = .staging
        #else
        let environment: AppEnvironment = .production
        #endif

        _container = StateObject(wrappedValue: DependencyContainer(environment: environment))

        // UI appearance setup
        setupAppearance()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(container.makeTransactionViewModel())
                .environmentObject(container.makeAccountsViewModel())
                // ... other ViewModels
                .environment(\.managedObjectContext, container.persistenceController.container.viewContext)
        }
    }
}
```

### Build Configurations
- **DEBUG**: Uses staging environment
- **RELEASE**: Uses production environment
- **Minimum iOS**: 15.0+
- **CloudKit**: Enabled for data sync

---

## Testing

### Testing Framework
**Framework**: Swift Testing (modern replacement for XCTest)

### Test Files
- `RepositoryTests.swift` (435 lines) - Repository layer tests
- `ExpenseTrackerTests.swift` - General unit tests
- `ExpenseTrackerUITests.swift` - UI automation tests
- `ExpenseTrackerUITestsLaunchTests.swift` - Launch performance tests

### Repository Tests Example
**File**: `ExpenseTracker/Tests/UnitTests/RepositoryTests.swift`

```swift
@Suite("Repository Tests")
struct RepositoryTests {
    var sut: CoreDataTransactionRepository
    var testContainer: NSPersistentContainer

    init() async throws {
        // Setup in-memory Core Data stack
        let container = NSPersistentContainer(name: "ExpenseTracker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        // ... load stores
    }

    @Test("Create transaction successfully")
    func createTransaction() async throws {
        // Given: Setup test data
        let account = Account(...)
        let category = Category(...)

        // When: Execute operation
        let created = try await sut.createTransaction(transaction)

        // Then: Assert results
        #expect(created.amount == 100)
        #expect(created.category?.id == category.id)
    }
}
```

### Test Coverage Areas
- Transaction CRUD operations
- Account management
- Category operations
- Filtering and search
- Split transactions
- Data persistence
- UI navigation
- Launch performance

### Testing Utilities
- In-memory Core Data for tests
- Mock services for isolated testing
- Preview data for SwiftUI previews
- Dependency container test factory

---

## Development Guidelines

### Code Organization
- **Feature-based modules**: Each feature has its own folder with Views, ViewModels, and Components
- **Protocol-driven design**: Services use protocols for testability
- **Dependency injection**: Centralized container for all dependencies
- **MARK comments**: Organize code sections within files

### Naming Conventions
- **Views**: Suffix with `View` (e.g., `TransactionListView`)
- **ViewModels**: Suffix with `ViewModel` (e.g., `TransactionViewModel`)
- **Services**: Suffix with `Service` (e.g., `CategorizationService`)
- **Protocols**: Suffix with `Protocol` (e.g., `TransactionRepositoryProtocol`)
- **Entities**: Suffix with `Entity` (e.g., `TransactionEntity`)

### SwiftUI Patterns
- **@State**: Local UI state
- **@StateObject**: ViewModel lifecycle tied to view
- **@EnvironmentObject**: Shared ViewModels across view hierarchy
- **@Environment**: System environment values
- **@FocusState**: Keyboard focus management

### Error Handling
- Use `AppError` enum for all app-specific errors
- Provide localized error messages
- Use severity levels for appropriate UI response
- Log errors for debugging

### Performance
- Use Combine publishers for reactive updates
- Batch fetch requests with prefetching
- Cache formatters (avoid recreation)
- Debounce search/filter updates
- Lazy loading for large lists

### Localization
- All user-facing strings in Ukrainian
- Use String catalogs for localization
- Number and date formatting with locale support

### Git Workflow
Recent commits follow conventional commit format:
- `feat:` - New features
- `fix:` - Bug fixes
- Feature branches: `claude/feature-name-{session-id}`

### Future Enhancements
- Banking API integration (placeholder exists)
- Machine learning for categorization
- Budget tracking and alerts
- Recurring transactions
- Receipt scanning
- Multi-currency support enhancement
- Export to more formats

---

## Default Categories

The app includes 15 default categories (Ukrainian names):

| Category | Icon | Purpose |
|----------|------|---------|
| Продукти | 🛒 | Groceries |
| Транспорт | 🚗 | Transportation |
| Здоров'я | 💊 | Healthcare |
| Розваги | 🎬 | Entertainment |
| Одяг | 👕 | Clothing |
| Зарплата | 💰 | Salary (income) |
| Комунальні | 🏠 | Utilities |
| Ресторани | 🍽️ | Restaurants |
| Освіта | 📚 | Education |
| Таксі | 🚕 | Taxi |
| Інше | 📦 | Other |

---

## Contact & Support

For issues and feature requests, please refer to the project repository.

**Built with**: Swift 5.5+, SwiftUI, Core Data, CloudKit
**License**: [Check repository for license information]
**Version**: See git tags for version history

---

*Last Updated: 2025-11-13*
*Documentation generated from codebase analysis*
