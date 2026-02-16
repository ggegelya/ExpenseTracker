# ExpenseTracker - Claude Code Guide

## Project Mission
Production-ready iOS expense tracking app for Ukrainian market. Replaces Telegram bot + Google Sheets while maintaining family transparency. Target: App Store release in 2-3 weeks, built to scale.

**Competitive Advantages:**
- Banking integration as core feature (Ukraine Open Banking, August 2025)
- Ukrainian market focus (UAH, Monobank/PrivatBank, Cyrillic)
- Smart categorization with Ukrainian merchant patterns
- Family transparency via Telegram broadcast

**Architecture Philosophy:**
- "Banking as Facts, Manual as Annotations" - bank transactions are immutable truth
- Offline-first with Core Data + CloudKit sync
- Progressive disclosure UI (minimalistic, information revealed on demand)
- Production patterns from day one (no prototypes)

## Tech Stack

- **UI**: SwiftUI (latest iOS 26 target)
- **Data**: Core Data + CloudKit, proper relationships (never foreign keys)
- **Architecture**: MVVM with Combine, Repository pattern
- **Testing**: Swift Testing framework
- **Concurrency**: async/await, @MainActor, Swift 6 ready
- **Localization**: Ukrainian with pluralization
- **Style**: 4-space indentation, Swift API Design Guidelines

## File Organization

```
ExpenseTracker/
├── App/
│   ├── Configuration/
│   │   ├── Environment.swift           # AppEnvironment enum (.production, .testing, .preview, .staging)
│   │   └── TestingConfiguration.swift  # UI testing flags
│   ├── DependencyContainer.swift       # DI container, factory methods, data seeding
│   ├── ExpenseTrackerApp.swift         # @main entry, ViewModel creation
│   └── MainTabView.swift              # Tab navigation (5 tabs)
├── Core/
│   ├── ErrorHandling/
│   │   ├── AppError.swift             # Unified error enum with severity
│   │   ├── ErrorHandlingService.swift # Centralized error → toast/alert routing
│   │   ├── ToastMessage.swift         # Toast model
│   │   ├── AlertMessage.swift         # Alert model
│   │   ├── ToastType.swift            # success/warning/error/info
│   │   ├── Components/
│   │   │   ├── ErrorAlertView.swift   # Alert presentation view
│   │   │   └── ToastView.swift        # Toast presentation view
│   │   └── Protocols/
│   │       └── ErrorHandlingServiceProtocol.swift
│   ├── Models/
│   │   ├── Transaction.swift          # Transaction struct (split support)
│   │   ├── Category.swift             # Category struct with displayName localization
│   │   ├── Account.swift              # Account struct with displayName, validation
│   │   ├── PendingTransaction.swift   # Banking queue model
│   │   └── TransactionType.swift      # expense/income/transferOut/transferIn
│   ├── Persistence/
│   │   ├── Persistence.swift          # PersistenceController (Core Data + CloudKit)
│   │   ├── ExpenseTracker.xcdatamodeld # Core Data model
│   │   └── Migrations/               # Model version migrations
│   ├── Repository/
│   │   ├── Implementation/
│   │   │   └── CoreDataTransactionRepository.swift  # Core Data implementation
│   │   └── Protocols/
│   │       └── TransactionRepositoryProtocol.swift  # Repository interface
│   └── Services/
│       ├── AnalyticsService.swift     # Event tracking + business analytics
│       ├── CategorizationService.swift # Ukrainian merchant pattern matching
│       ├── CategoryMigrationService.swift # Ukrainian→English key migration
│       ├── DataSeeder.swift           # Initial data + preview data seeding
│       ├── ExportService.swift        # CSV export with Ukrainian formatting
│       └── Banking/                   # (in development)
├── Features/
│   ├── Accounts/
│   │   ├── AccountsView.swift
│   │   ├── AccountsViewModel.swift
│   │   └── Components/               # AccountRow, AccountDetailView, AddAccountView
│   ├── Analytics/
│   │   ├── AnalyticsView.swift
│   │   ├── AnalyticsViewModel.swift
│   │   └── Components/               # Charts, summary cards
│   ├── PendingQueue/
│   │   ├── PendingTransactionsView.swift
│   │   ├── PendingTransactionViewModel.swift
│   │   └── Components/               # ProcessPendingView, BatchProcessingView
│   ├── QuickEntry/
│   │   ├── QuickEntryView.swift       # Main entry UI (hero amount)
│   │   └── Components/               # 12 extracted subcomponents
│   └── Transactions/
│       ├── TransactionListView.swift
│       ├── TransactionViewModel.swift  # Primary ViewModel (CRUD, filters, bulk ops, splits)
│       └── Components/               # TransactionRow, DetailView, SplitView, FilterView
├── Shared/
│   ├── Constants/Spacing.swift
│   ├── Extensions/                    # Color+Hex, Decimal+Extensions, View+Extensions
│   ├── Utilities/Formatters.swift     # Reusable NumberFormatter/DateFormatter
│   └── Views/                         # FilterView, MonthSummaryCard, EmptyStateView, LoadingView
├── Resources/Assets.xcassets
└── Localizable.xcstrings              # Ukrainian translations

Tests/
├── IntegrationTests/
├── PerformanceTests/
├── TestUtilities/
│   ├── MockData.swift                 # Factory methods (MockTransaction, MockCategory, MockAccount, etc.)
│   ├── Mocks/
│   │   ├── MockTransactionRepository.swift  # Call tracking + error injection
│   │   ├── MockAnalyticsService.swift
│   │   ├── MockCategorizationService.swift
│   │   ├── MockErrorHandlingService.swift
│   │   └── MockExportService.swift
│   └── TestHelpers.swift              # AsyncTestUtilities, DateGenerator, DecimalComparison
├── UITests/                           # 6 UI test files
└── UnitTests/                         # 14+ unit test files
```

**Key Files:**
- `Persistence.swift` — Core Data + CloudKit setup (`PersistenceController`)
- `TransactionRepositoryProtocol.swift` — Primary data access interface
- `CoreDataTransactionRepository.swift` — Core Data implementation
- `DependencyContainer.swift` — DI, factory methods, initial data seeding
- `ErrorHandlingService.swift` — Centralized error → toast/alert routing
- `CategorizationService.swift` — Ukrainian merchant pattern matching
- `QuickEntryView.swift` — Main entry UI (hero amount + metadata pills)
- `Localizable.xcstrings` — Ukrainian translations

## Environment Configuration

**Modes** (in `Configuration/Environment.swift`):
- `.production` — Live app with persistent Core Data + CloudKit
- `.testing` — In-memory store for unit tests
- `.preview` — In-memory with seeded data for SwiftUI previews
- `.staging` — Production-like, separate environment

Use `DependencyContainer.makeForTesting()` or `.makeForPreviews()` for respective environments.

## Architecture Patterns

### Core Data Model (CRITICAL: Always use relationships, never foreign keys)

```
TransactionEntity
├── amount: Decimal
├── date: Date
├── notes: String?
├── category: CategoryEntity (relationship)
├── fromAccount: AccountEntity? (relationship)
├── toAccount: AccountEntity? (relationship)
├── parentTransaction: TransactionEntity? (relationship)
├── splitTransactions: Set<TransactionEntity> (inverse)
├── bankTransactionId: String?
└── isReconciled: Bool

CategoryEntity
├── name: String (stable English key, e.g. "groceries")
├── icon: String (SF Symbol)
├── colorHex: String
├── isSystem: Bool
├── sortOrder: Int32
└── transactions: Set<TransactionEntity> (inverse)

AccountEntity
├── name: String (stable key, e.g. "default_card")
├── tag: String
├── balance: Decimal
├── isDefault: Bool
├── type: String (AccountType raw value)
├── currency: String (Currency raw value)
├── expenseTransactions: Set<TransactionEntity> (inverse)
└── incomeTransactions: Set<TransactionEntity> (inverse)

PendingTransactionEntity
├── bankTransactionId: String
├── amount: Decimal
├── descriptionText: String
├── merchantName: String?
├── type: String
├── status: String
├── account: AccountEntity (relationship)
├── suggestedCategory: CategoryEntity? (relationship)
└── confidence: Float
```

### Localization Pattern — displayName

Internal names are **stable English keys** (`"groceries"`, `"default_card"`). Display uses `displayName` computed property:

```swift
// Category.swift
var displayName: String {
    let key = "category.\(name)"
    let localized = String(localized: String.LocalizationValue(key))
    return localized == key ? name : localized
}

// Account.swift
var displayName: String {
    let key = "account.\(name)"
    let localized = String(localized: String.LocalizationValue(key))
    return localized == key ? name : localized
}
```

**Rule:** Use `displayName` for user-facing text. Use `name` for persistence, matching, and accessibility identifiers.

### Error Handling Architecture

```
ErrorHandlingServiceProtocol
├── handle(_ error: AppError, context: String?)  — routes by severity
├── showToast(_ message: String, type: ToastType) — transient feedback
├── showAlert(_ error: AppError, retryAction:)    — blocking errors
├── dismissAlert() / dismissToast()
└── handleAny(_ error: Error, context:) -> AppError  — maps any Error → AppError

AppError (enum)
├── severity: .low → toast, .medium/.high/.critical → alert
├── isRetryable: Bool
├── recoverySuggestion: String?
└── Cases: .invalidAmount, .accountRequired, .saveFailed, .networkError, .syncFailed, etc.

Flow: ViewModel → errorHandler.handleAny() → ErrorHandlingService → toast/alert
UI:   MainTabView observes ErrorHandlingService (environmentObject) → ToastView / .alert()
```

### MVVM with Repository

```swift
// ViewModel — all ViewModels receive errorHandler via DI
@MainActor
final class TransactionViewModel: ObservableObject {
    private let repository: TransactionRepositoryProtocol
    private let categorizationService: CategorizationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let errorHandler: ErrorHandlingServiceProtocol

    init(repository:, categorizationService:, analyticsService:, errorHandler:) { ... }
}

// Repository protocol — @MainActor, async/await, Combine publishers
@MainActor
protocol TransactionRepositoryProtocol: AnyObject {
    func createTransaction(_ transaction: Transaction) async throws -> Transaction
    func updateTransaction(_ transaction: Transaction) async throws -> Transaction
    func deleteTransaction(_ transaction: Transaction) async throws
    // ... accounts, categories, pending, batch, atomic operations
    var transactionsPublisher: AnyPublisher<[Transaction], Never> { get }
    var accountsPublisher: AnyPublisher<[Account], Never> { get }
    var categoriesPublisher: AnyPublisher<[Category], Never> { get }
}
```

### Testing Patterns

**Mock Infrastructure** — all mocks support call tracking + error injection:

```swift
// MockTransactionRepository
let mock = MockTransactionRepository(
    transactions: [...],
    categories: [...],
    accounts: [...]
)
mock.shouldThrowError = true  // error injection
mock.wasCalled("createTransaction(_:)")  // call verification
mock.callCount(for: "deleteTransaction(_:)")  // count checks

// Test pattern
@Suite("ViewModel Tests", .serialized) @MainActor
struct TransactionViewModelTests {
    var sut: TransactionViewModel
    var mockRepository: MockTransactionRepository

    init() async throws {
        mockRepository = MockTransactionRepository()
        sut = TransactionViewModel(
            repository: mockRepository,
            categorizationService: MockCategorizationService(),
            analyticsService: MockAnalyticsService(),
            errorHandler: MockErrorHandlingService()
        )
    }
}
```

### Protocols Inventory

| Protocol | File | Implementations |
|----------|------|----------------|
| `TransactionRepositoryProtocol` | `Core/Repository/Protocols/` | `CoreDataTransactionRepository`, `MockTransactionRepository` |
| `CategorizationServiceProtocol` | `Core/Services/CategorizationService.swift` | `CategorizationService`, `MockCategorizationService` |
| `AnalyticsServiceProtocol` | `Core/Services/AnalyticsService.swift` | `AnalyticsService`, `MockAnalyticsService` |
| `ExportServiceProtocol` | `Core/Services/ExportService.swift` | `ExportService`, `MockExportService` |
| `ErrorHandlingServiceProtocol` | `Core/ErrorHandling/Protocols/` | `ErrorHandlingService`, `MockErrorHandlingService` |
| `DependencyContainerProtocol` | `App/DependencyContainer.swift` | `DependencyContainer` |

## Code Standards

### Production Patterns

```swift
// Dependency injection — all ViewModels receive dependencies via init
class TransactionListViewModel {
    init(repository: TransactionRepositoryProtocol, errorHandler: ErrorHandlingServiceProtocol) { ... }
}

// Proper relationships with inverse
extension TransactionEntity {
    @NSManaged var category: CategoryEntity?
}

// Error handling (never fatalError in production)
func saveTransaction(_ transaction: Transaction) async throws {
    do {
        try await repository.save(transaction)
    } catch {
        let appError = errorHandler.handleAny(error, context: "Saving transaction")
        self.error = appError
    }
}

// Performance: Reuse formatters (use Formatters utility)
Formatters.currencyStringUAH(amount: amount, minFractionDigits: 2, maxFractionDigits: 2)

// Performance: Prefetch relationships
fetchRequest.relationshipKeyPathsForPrefetching = ["category", "fromAccount", "toAccount", "splitTransactions"]

// Localization — use displayName for user-facing, name for internal
Text(category.displayName)  // user-facing
category.name == "groceries" // internal matching

// Testing
@Test("Transaction saves with category relationship")
func testTransactionSaveWithCategory() async throws {
    let repository = MockTransactionRepository()
    // ...
    #expect(saved.category?.name == "groceries")
}
```

### Anti-Patterns

**Data Layer:**
- Foreign keys (`categoryId: UUID`) instead of relationships
- Denormalized data (`categoryName: String` instead of `category: CategoryEntity`)
- UserDefaults for sensitive data
- Synchronous Core Data on main thread

**Architecture:**
- Business logic in Views
- Direct Core Data access in ViewModels
- Missing dependency injection

**SwiftUI:**
- Creating formatters in view body (expensive!)
- Wrong use of @StateObject/@ObservedObject
- Missing .task for async work

**Performance:**
- Missing relationship prefetching
- Formatter recreation in loops
- Expensive operations in view body

## SwiftUI Patterns

**UI Philosophy:**
- Minimalistic "hero" layouts (one primary element, subtle secondary info as pills/chips)
- Progressive disclosure (start minimal, reveal on demand)
- Platform idioms (iOS Mail compose, Apple Wallet style)
- Ukrainian business rules (no zero amounts, UAH currency)

## Banking Integration

**Current State:**
- Monobank API client in development
- OAuth2 flow planned (requires Vapor backend)
- Pending transaction processing implemented

**Architecture:**
```
[iOS App] <-> [Vapor Backend] <-> [Bank APIs]
   |              |
[Core Data]  [Token Storage]
   |
[CloudKit]
```

**Key Decisions:**
- Vapor (Swift) for code sharing
- OAuth2 tokens server-side only (security)
- Device stores account references, not credentials

## Commands

```bash
# Build
xcodebuild -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test
xcodebuild test -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=iPhone 16'

# Swift 6 check
swift build -Xswiftc -strict-concurrency=complete
```

## Quick Reference

### Ukrainian Formatting
```swift
// Currency (always UAH) — use Formatters utility
Formatters.currencyStringUAH(amount: 1234.56, minFractionDigits: 2, maxFractionDigits: 2)
// → "1 234,56 ₴"

// Multi-currency
Formatters.currencyString(amount: 100, currency: .usd, minFractionDigits: 0, maxFractionDigits: 2)
```

### Code Review Checklist
1. Core Data relationships (no foreign keys)
2. Repository pattern (no direct Core Data in ViewModels)
3. Ukrainian localization (displayName for user-facing, name for internal)
4. Error handling (errorHandler DI, no fatalError in production)
5. Performance (formatters reused via Formatters utility, prefetching)
6. Security (Keychain for sensitive data, sanitized logs in release)
7. Tests included (unit + integration)
8. Swift 6 ready (@MainActor, Sendable)

### Task Complete When
- Code follows patterns above
- Tests pass
- No performance regressions
- Ukrainian localization complete
- Accessible (VoiceOver, Dynamic Type)
- Production-ready error handling

## Current Status

**Completed:**
- QuickEntryView redesign (hero amount + metadata pills)
- Unified transaction detail components
- Smart Ukrainian merchant categorization
- Localization infrastructure overhaul (English keys + displayName pattern)
- QuickEntry decomposition into 12 subcomponents
- Centralized error handling service
- Category key migration (Ukrainian → English)
- Error handling wired to app UI (toast/alert)
- Atomic split transaction operations
- Privacy: sanitized logs, secured exports
- Account displayName pattern
- DataSeeder extraction, injectable UserDefaults

**Next Milestones:**
1. Monobank OAuth2 + transaction fetching
2. Export functionality enhancements (PDF)
3. App Store submission
4. Vapor backend (OAuth token storage)
5. Enhanced analytics

## Deferred (post-launch)

| Item | Reason |
|------|--------|
| Split TransactionRepositoryProtocol into domain protocols | Touches every ViewModel, mock, DI container. Too risky pre-launch. |
| Consolidate ViewModel state (25+ @Published -> structs) | Changes every view binding. High regression risk. |
| Navigation router | TabView adequate for current complexity. Needed when banking flows land. |

## Guidelines for Claude Code

- **Correctness > speed**: Production code for real users
- **Ask before big changes**: Small refactors OK, architecture changes need discussion
- **Test everything**: Unit + integration tests required
- **Ukrainian context is mandatory**: Currency, localization, bank patterns
- **Performance matters**: Smooth UI is critical
- **Security is non-negotiable**: Keychain for tokens, never log sensitive data

When in doubt, follow existing code patterns.
