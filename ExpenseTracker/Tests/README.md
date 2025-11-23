# ExpenseTracker Tests

## Overview

This project uses Xcode Test Plans and Swift Testing framework to ensure code quality and reliability. The test suite covers unit tests, integration tests, performance tests, and UI tests.

## Test Plan

### TestPlan.xctestplan

The project currently has **one main test plan** (`TestPlan.xctestplan`) that includes:

- **ExpenseTrackerTests** - Unit, integration, and performance tests
- **ExpenseTrackerUITests** - UI automation tests
- **Test timeouts enabled** - Prevents hanging tests

**Run all tests:**
```bash
xcodebuild test -scheme ExpenseTracker \
  -testPlan TestPlan \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Run with code coverage:**
```bash
xcodebuild test -scheme ExpenseTracker \
  -testPlan TestPlan \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

**Run only unit tests (fast):**
```bash
xcodebuild test -scheme ExpenseTracker \
  -only-testing:ExpenseTrackerTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Run only UI tests:**
```bash
xcodebuild test -scheme ExpenseTracker \
  -only-testing:ExpenseTrackerUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Running Tests in Xcode

1. **Run all tests:** ⌘U
2. **Run specific test:** Click diamond next to test function/suite
3. **Run specific test class:** Click diamond next to class name
4. **View test results:** Test Navigator (⌘6)
5. **View code coverage:** Report Navigator (⌘9) → Coverage tab

**Enable code coverage:**
- Product → Scheme → Edit Scheme → Test → Options
- Check "Code Coverage" and select targets to gather coverage for

## Test Configuration

### Environment Configuration

Tests use the `.testing` environment mode (configured in `Configuration/Environment.swift`):
- In-memory Core Data store (no persistence)
- Isolated from production data
- Fast test execution

### Launch Arguments for UI Tests

Configure in test setUp or scheme settings:
- `-UITesting` - Indicates UI tests are running
- `-DisableAnimations` - Disables animations for faster tests
- `-ResetAppState` - Clears app state before tests

Example:
```swift
override func setUpWithError() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-UITesting", "-ResetAppState", "-DisableAnimations"]
    app.launch()
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme ExpenseTracker \
            -testPlan TestPlan \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults.xcresult

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          xcode: true
          xcode_archive_path: TestResults.xcresult
```

## Coverage Goals

Target coverage percentages:
- **Repository Layer:** 95%+
- **Service Layer:** 90%+
- **ViewModel Layer:** 85%+
- **Overall:** 80%+

Current coverage can be viewed in Xcode's Report Navigator after running tests with coverage enabled.

## Best Practices

1. **Run unit tests frequently** during development for fast feedback
2. **Run all tests before committing** to ensure nothing broke
3. **Use `-only-testing` flag** to run specific test suites during development
4. **Enable code coverage** for major changes to verify test coverage
5. **Keep tests fast** - use in-memory stores, disable animations
6. **Isolate tests** - each test should be independent
7. **Test Ukrainian localization** - verify currency (UAH) and date formatting
8. **Use Swift Testing framework** (`@Test`, `#expect`) for new tests

## Troubleshooting

### Tests timing out
- Test plan has `testTimeoutsEnabled: true` by default
- Check for infinite loops or async operations without proper completion
- Ensure Core Data operations complete

### Flaky tests
- Ensure tests are isolated and don't depend on execution order
- Use proper async/await patterns
- Verify animations are disabled in UI tests
- Check for race conditions in concurrent code

### Code coverage not showing
- Enable in scheme: Edit Scheme → Test → Options → Code Coverage
- Run tests with `-enableCodeCoverage YES` flag
- View in Report Navigator (⌘9) → Coverage tab

### UI tests failing
- Ensure `-UITesting` and `-DisableAnimations` launch arguments are set
- Use accessibility identifiers for reliable element selection
- Add proper wait conditions for async UI updates
- Reset app state with `-ResetAppState`

### Thread safety issues
- Use `@MainActor` for UI-related code
- Prefer Swift Concurrency (async/await) over GCD
- Enable Thread Sanitizer in scheme settings to detect data races

### Memory leaks
- Check for retain cycles in closures (use `[weak self]`)
- Verify `deinit` is called when objects deallocate
- Enable Address Sanitizer in scheme settings

## Test Structure

```
ExpenseTracker/Tests/
├── UnitTests/                     Target: ExpenseTrackerTests
│   ├── ExpenseTrackerTests.swift  (legacy - being migrated)
│   ├── RepositoryTests.swift
│   ├── LocalizationTests.swift
│   ├── AnalyticsServiceTests.swift
│   ├── CategorizationServiceTests.swift
│   ├── ExportServiceTests.swift
│   ├── TransactionViewModelTests.swift
│   ├── AccountsViewModelTests.swift
│   └── PendingTransactionsViewModelTests.swift
│
├── IntegrationTests/              Target: ExpenseTrackerTests
│   └── TransactionFlowIntegrationTests.swift
│
├── PerformanceTests/              Target: ExpenseTrackerTests
│   └── RepositoryPerformanceTests.swift
│
├── UITests/                       Target: ExpenseTrackerUITests
│   ├── ExpenseTrackerUITests.swift
│   ├── QuickEntryUITests.swift
│   ├── TransactionListUITests.swift
│   └── ExpenseTrackerUITestsLaunchTests.swift
│
└── TestUtilities/                 Shared utilities
    ├── Mocks/
    │   ├── MockTransactionRepository.swift
    │   ├── MockCategorizationService.swift
    │   ├── MockAnalyticsService.swift
    │   └── MockExportService.swift
    ├── MockData.swift
    └── TestHelpers.swift
```

### Test Categories

**Unit Tests** (Fast, ~5-10 seconds total)
- Repository layer tests (Core Data operations)
- Service layer tests (categorization, analytics, export)
- ViewModel tests (business logic, state management)
- Localization tests (Ukrainian formatting)

**Integration Tests** (Medium, ~5-10 seconds)
- End-to-end transaction flows
- Repository + Service integration
- Core Data relationship testing

**Performance Tests** (Medium, ~5-10 seconds)
- Core Data query performance
- Large dataset operations
- Memory usage benchmarks

**UI Tests** (Slower, ~15-20 seconds total)
- Critical user flows (quick entry, transaction list)
- Navigation and interaction
- Launch tests

## Writing New Tests

### Swift Testing Framework (Unit Tests)

**Use for:** New unit tests, service tests, ViewModel tests

```swift
import Testing
@testable import ExpenseTracker

@Suite("Transaction Repository Tests")
struct TransactionRepositoryTests {

    @Test("Saves transaction with category relationship")
    func saveTransactionWithCategory() async throws {
        // Given
        let repository = InMemoryTransactionRepository()
        let category = Category(name: "Food", icon: "fork.knife", colorHex: "#FF6B6B")
        let transaction = Transaction(amount: 100, category: category)

        // When
        try await repository.save(transaction)
        let saved = try await repository.fetch(by: transaction.id)

        // Then
        #expect(saved.category?.name == "Food")
        #expect(saved.amount == 100)
    }

    @Test("Handles nil category gracefully")
    func saveTransactionWithoutCategory() async throws {
        let repository = InMemoryTransactionRepository()
        let transaction = Transaction(amount: 50, category: nil)

        try await repository.save(transaction)
        let saved = try await repository.fetch(by: transaction.id)

        #expect(saved.category == nil)
    }
}
```

### XCTest Framework (UI Tests)

**Use for:** UI automation tests

```swift
import XCTest

final class QuickEntryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ResetAppState", "-DisableAnimations"]
        app.launch()
    }

    func testAddTransaction() throws {
        let app = XCUIApplication()

        // Navigate to quick entry
        app.buttons["quickEntryButton"].tap()

        // Enter amount
        app.textFields["amountField"].tap()
        app.textFields["amountField"].typeText("100")

        // Select category
        app.buttons["categoryPicker"].tap()
        app.buttons["category_food"].tap()

        // Save
        app.buttons["saveButton"].tap()

        // Verify
        XCTAssert(app.staticTexs["₴100"].waitForExistence(timeout: 2))
    }
}
```

### Adding Tests to Xcode

**Option 1: File Inspector**
1. Select test file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Check target membership (`ExpenseTrackerTests` or `ExpenseTrackerUITests`)

**Option 2: Build Phases**
1. Select target in project settings
2. Build Phases → Compile Sources
3. Click **+** and add test file

Tests are automatically included in `TestPlan.xctestplan` once added to targets.

## Testing Utilities

### Mock Repositories
Use `MockTransactionRepository` and other mocks from `TestUtilities/Mocks/` for fast, isolated tests.

```swift
@Test("ViewModel handles save error")
func handleSaveError() async throws {
    let mockRepo = MockTransactionRepository()
    mockRepo.shouldFail = true
    let viewModel = TransactionViewModel(repository: mockRepo)

    await viewModel.save()

    #expect(viewModel.errorMessage != nil)
}
```

### Test Data
Use `MockData.swift` for consistent test fixtures:

```swift
let testTransaction = MockData.transaction(amount: 100, category: .food)
let testCategory = MockData.category(.food)
```

## Maintenance

- **Add tests for new features** - every PR should include tests
- **Run tests before committing** - catch issues early
- **Review coverage regularly** - aim for 80%+ overall
- **Keep tests fast** - slow tests won't be run frequently
- **Update README** - document new test patterns or utilities

## Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Project Architecture Guidelines](../../../CLAUDE.md)
- [Apple's Testing Guide](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)
