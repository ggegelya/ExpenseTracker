# ExpenseTracker Agent Guide

This file is for coding agents and contributors working in this repository.
Use it as the operational guide for safe, high-signal changes.

## Quick Start

### Build
```bash
xcodebuild -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Test (unit + UI)
```bash
xcodebuild test -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Useful test flags
`TestingConfiguration` reads these environment/argument switches:
- `IS_TESTING=1`
- `MOCK_DATA_ENABLED=1`
- `START_EMPTY=1`
- `DISABLE_ANIMATIONS=1`
- Launch args: `-UITesting`, `-DisableAnimations`, `-ResetAppState`

## Project Shape

- App entry: `ExpenseTracker/App/ExpenseTrackerApp.swift`
- DI container: `ExpenseTracker/App/DependencyContainer.swift`
- Environment config: `ExpenseTracker/App/Configuration/Environment.swift`
- Core data stack: `ExpenseTracker/Core/Persistence/Persistence.swift`
- Repository impl: `ExpenseTracker/Core/Repository/Implementation/CoreDataTransactionRepository.swift`
- Domain models: `ExpenseTracker/Core/Models/`
- Features: `ExpenseTracker/Features/{QuickEntry,Transactions,PendingQueue,Accounts,Analytics}`
- Shared UI/utilities: `ExpenseTracker/Shared/`
- Tests: `ExpenseTracker/Tests/`

## Non-Negotiable Patterns

### 1) Dependency injection first
- Add new services/protocols through `DependencyContainer`.
- Inject protocols into view models; avoid direct concrete coupling in feature code.
- Keep view model creation centralized in `DependencyContainer` factory methods.

### 2) MainActor view models, async repository
- Feature view models are `@MainActor` and own UI state.
- Repository is the boundary for persistence logic; avoid Core Data logic in features.
- Use async/await and avoid ad-hoc detached concurrency for UI state.

### 3) Centralized error handling
- Use `ErrorHandlingServiceProtocol` in view models.
- Prefer `errorHandler.handleAny(error, context:)` to map into `AppError`.
- Keep user-facing error text in localization resources, not inline strings.

### 4) Localization discipline
- Use `String(localized:)` for all user-facing text.
- Source of truth is `ExpenseTracker/Localizable.xcstrings`.
- Do not hardcode Ukrainian/English literals in views/view models.

### 5) Logging discipline
- Prefer `os.Logger`; avoid `print` in app/runtime code.
- Never log sensitive transaction contents (merchant, full description, amounts) unless explicitly required and sanitized.

## Domain Invariants (Important)

### Category naming
- `Category.name` is a stable internal key (for example `groceries`, `taxi`, `other`).
- Display text must use `Category.displayName`, not `Category.name`.
- If you change category keys, provide a migration/alias strategy for existing persisted data.

### Account model
- `AccountType` and `Currency` are persisted by raw value and mapped in repository conversion helpers.
- Keep mapping backward-compatible when adding/changing enum cases.

### Split transactions
- Parent/child split semantics are special-case logic.
- Parent transactions may represent summary values; children carry split details.
- Bulk operations must avoid processing both parent and child as separate destructive actions.

### Pending transactions
- Suggested category is now a relationship in Core Data.
- Keep pending processing and dismissal behavior aligned with repository contracts.

## Core Data Rules

- Model file: `ExpenseTracker/Core/Persistence/ExpenseTracker.xcdatamodeld/.../contents`
- Repository conversion helpers are critical; update both directions when schema changes:
  - entity -> domain mapping
  - domain -> entity mapping
- Use repository context helpers (`performBackgroundTask`, `performOnViewContext`) for thread safety.
- When schema/relationship changes happen, run full tests and validate seeded preview/testing paths.

## Feature-Specific Guidance

### Quick Entry
- Keep `QuickEntryView` composition-based; prefer extracting components over enlarging the file.
- Preserve accessibility identifiers used by UI tests.

### Transactions
- Filtering and bulk actions are test-sensitive.
- `filteredTransactions` and split expansion behavior should remain deterministic for tests.

### Accounts
- Deletion constraints matter: cannot remove last account; cannot remove account with linked transactions.
- Surface recoverable errors to UI rather than silently swallowing.

### Analytics
- Date-range logic must be explicit about inclusive/exclusive bounds.
- Recompute pipelines should remain predictable and avoid unnecessary work on main thread.

## Testing Expectations

### Unit tests
- Framework: Swift Testing (`@Suite`, `@Test`).
- Update/add tests whenever changing:
  - filtering logic
  - split transaction behavior
  - category/account invariants
  - localization-sensitive behavior

### UI tests
- Framework: XCTest.
- Keep stable accessibility identifiers (avoid text-only selectors).
- When changing tab/view flows, update UI tests in `ExpenseTracker/Tests/UITests/`.

## Checklists

### When adding a service
1. Define protocol.
2. Implement concrete type.
3. Register in `DependencyContainer`.
4. Inject where needed.
5. Add/update mocks in `ExpenseTracker/Tests/TestUtilities/Mocks/`.
6. Add focused tests.

### When changing strings/UI copy
1. Add/update keys in `Localizable.xcstrings`.
2. Use `String(localized:)` in code.
3. Verify no user-facing hardcoded literals remain.
4. Run localization-related tests.

### When changing persistence/model
1. Update model.
2. Update repository mappings.
3. Validate preview seed and testing seed flows.
4. Run full test suite.

## Known Pitfalls To Avoid

- Do not use `category.name` for user-facing labels.
- Do not compare localized strings in business logic.
- Do not bypass repository abstractions for data writes.
- Do not introduce duplicated source-of-truth logic between view models and services.
- Do not leave partial split-state mutations on failure paths.

## Quality Bar For PRs

- Conventional commits (`feat:`, `fix:`, `refactor:`).
- Include validation steps (build + tests run).
- Include screenshots/recording for UI-impacting changes.
- Explicitly call out migrations or seed-data impacts when persistence/domain keys change.
