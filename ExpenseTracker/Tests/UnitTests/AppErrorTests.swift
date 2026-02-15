//
//  AppErrorTests.swift
//  ExpenseTracker
//
//  Tests for AppError covering errorDescription, recoverySuggestion, isRetryable,
//  severity, Equatable conformance, and init(from:) mappings.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("AppError Tests")
struct AppErrorTests {

    // MARK: - Error Description Tests

    @Test("errorDescription returns non-nil for all simple cases")
    func errorDescriptionReturnsNonNilForAllCases() {
        let cases: [AppError] = [
            .invalidAmount,
            .insufficientFunds,
            .networkUnavailable,
            .bankingServiceUnavailable,
            .categoryRequired,
            .accountRequired,
            .dataCorruption,
            .syncFailed,
            .authenticationFailed,
            .permissionDenied,
            .bankTokenExpired,
            .bankAccountNotFound,
            .bankTransactionFailed,
            .dailyLimitExceeded
        ]

        for error in cases {
            #expect(error.errorDescription != nil, "errorDescription should not be nil for \(error)")
            #expect(!error.errorDescription!.isEmpty, "errorDescription should not be empty for \(error)")
        }
    }

    @Test("repositoryError errorDescription delegates to RepositoryError")
    func repositoryErrorDelegatesToRepoError() {
        let repoError = RepositoryError.entityNotFound
        let appError = AppError.repositoryError(repoError)

        #expect(appError.errorDescription == repoError.localizedDescription)
    }

    // MARK: - Recovery Suggestion Tests

    @Test("recoverySuggestion returns non-nil for applicable errors")
    func recoverySuggestionReturnsNonNilForApplicable() {
        let errorsWithRecovery: [AppError] = [
            .networkUnavailable,
            .bankingServiceUnavailable,
            .bankTokenExpired,
            .dataCorruption,
            .dailyLimitExceeded
        ]

        for error in errorsWithRecovery {
            #expect(error.recoverySuggestion != nil, "recoverySuggestion should not be nil for \(error)")
            #expect(!error.recoverySuggestion!.isEmpty, "recoverySuggestion should not be empty for \(error)")
        }
    }

    @Test("recoverySuggestion returns nil for errors without recovery")
    func recoverySuggestionReturnsNilForOthers() {
        let errorsWithoutRecovery: [AppError] = [
            .invalidAmount,
            .insufficientFunds,
            .categoryRequired,
            .accountRequired,
            .syncFailed,
            .authenticationFailed,
            .permissionDenied,
            .bankAccountNotFound,
            .bankTransactionFailed
        ]

        for error in errorsWithoutRecovery {
            #expect(error.recoverySuggestion == nil, "recoverySuggestion should be nil for \(error)")
        }
    }

    // MARK: - isRetryable Tests

    @Test("isRetryable returns true for retryable errors")
    func isRetryableTrueForRetryableErrors() {
        let retryableErrors: [AppError] = [
            .networkUnavailable,
            .bankingServiceUnavailable,
            .syncFailed
        ]

        for error in retryableErrors {
            #expect(error.isRetryable, "\(error) should be retryable")
        }
    }

    @Test("isRetryable returns false for non-retryable errors")
    func isRetryableFalseForNonRetryableErrors() {
        let nonRetryableErrors: [AppError] = [
            .invalidAmount,
            .insufficientFunds,
            .categoryRequired,
            .accountRequired,
            .dataCorruption,
            .authenticationFailed,
            .permissionDenied,
            .bankTokenExpired,
            .bankAccountNotFound,
            .bankTransactionFailed,
            .dailyLimitExceeded
        ]

        for error in nonRetryableErrors {
            #expect(!error.isRetryable, "\(error) should not be retryable")
        }
    }

    // MARK: - Severity Tests

    @Test("severity returns critical for dataCorruption and authenticationFailed")
    func severityCriticalForCorrectCases() {
        #expect(AppError.dataCorruption.severity == .critical)
        #expect(AppError.authenticationFailed.severity == .critical)
    }

    @Test("severity returns high for bankTokenExpired and syncFailed")
    func severityHighForCorrectCases() {
        #expect(AppError.bankTokenExpired.severity == .high)
        #expect(AppError.syncFailed.severity == .high)
    }

    @Test("severity returns medium for networkUnavailable and bankingServiceUnavailable")
    func severityMediumForCorrectCases() {
        #expect(AppError.networkUnavailable.severity == .medium)
        #expect(AppError.bankingServiceUnavailable.severity == .medium)
    }

    @Test("severity returns low for remaining errors")
    func severityLowForRemainingCases() {
        let lowSeverityCases: [AppError] = [
            .invalidAmount,
            .insufficientFunds,
            .categoryRequired,
            .accountRequired,
            .permissionDenied,
            .bankAccountNotFound,
            .bankTransactionFailed,
            .dailyLimitExceeded
        ]

        for error in lowSeverityCases {
            #expect(error.severity == .low, "\(error) should have low severity")
        }
    }

    // MARK: - Equatable Tests

    @Test("Equatable same case returns true")
    func equatableSameCaseReturnsTrue() {
        #expect(AppError.invalidAmount == AppError.invalidAmount)
        #expect(AppError.networkUnavailable == AppError.networkUnavailable)
        #expect(AppError.dataCorruption == AppError.dataCorruption)
        #expect(AppError.bankTokenExpired == AppError.bankTokenExpired)
    }

    @Test("Equatable different cases returns false")
    func equatableDifferentCasesReturnsFalse() {
        #expect(AppError.invalidAmount != AppError.insufficientFunds)
        #expect(AppError.networkUnavailable != AppError.syncFailed)
        #expect(AppError.dataCorruption != AppError.authenticationFailed)
    }

    @Test("Equatable repositoryError compares descriptions")
    func equatableRepositoryErrorComparesDescriptions() {
        let error1 = AppError.repositoryError(.entityNotFound)
        let error2 = AppError.repositoryError(.entityNotFound)
        let error3 = AppError.repositoryError(.contextUnavailable)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Equatable repositoryError vs simple case returns false")
    func equatableRepositoryErrorVsSimpleCase() {
        let repoError = AppError.repositoryError(.entityNotFound)
        #expect(repoError != AppError.invalidAmount)
    }

    // MARK: - Init from RepositoryError Tests

    @Test("init(from: RepositoryError) maps to repositoryError case")
    func initFromRepositoryErrorMapsCorrectly() {
        let repoErrors: [RepositoryError] = [
            .contextUnavailable,
            .entityNotFound,
            .invalidData("test"),
            .migrationRequired,
            .conflictDetected("test conflict")
        ]

        for repoError in repoErrors {
            let appError = AppError(from: repoError)
            #expect(appError == .repositoryError(repoError))
        }
    }

    @Test("init(from: RepositoryError) preserves error description")
    func initFromRepositoryErrorPreservesDescription() {
        let repoError = RepositoryError.invalidData("Missing required field")
        let appError = AppError(from: repoError)

        #expect(appError.errorDescription == repoError.localizedDescription)
    }

    // MARK: - Init from URLError Tests

    @Test("init(from: URLError) maps notConnectedToInternet to networkUnavailable")
    func initFromURLErrorNotConnected() {
        let urlError = URLError(.notConnectedToInternet)
        let appError = AppError(from: urlError)

        #expect(appError == .networkUnavailable)
    }

    @Test("init(from: URLError) maps networkConnectionLost to networkUnavailable")
    func initFromURLErrorConnectionLost() {
        let urlError = URLError(.networkConnectionLost)
        let appError = AppError(from: urlError)

        #expect(appError == .networkUnavailable)
    }

    @Test("init(from: URLError) maps userAuthenticationRequired to authenticationFailed")
    func initFromURLErrorAuthRequired() {
        let urlError = URLError(.userAuthenticationRequired)
        let appError = AppError(from: urlError)

        #expect(appError == .authenticationFailed)
    }

    @Test("init(from: URLError) maps other codes to networkUnavailable")
    func initFromURLErrorOtherCodes() {
        let urlError = URLError(.timedOut)
        let appError = AppError(from: urlError)

        #expect(appError == .networkUnavailable)
    }

    // MARK: - RepositoryError Tests

    @Test("RepositoryError errorDescription returns non-nil for all cases")
    func repositoryErrorDescriptionReturnsNonNil() {
        let cases: [RepositoryError] = [
            .contextUnavailable,
            .entityNotFound,
            .invalidData("test detail"),
            .saveFailed(underlying: NSError(domain: "Test", code: -1)),
            .fetchFailed(underlying: NSError(domain: "Test", code: -1)),
            .migrationRequired,
            .conflictDetected("conflict detail")
        ]

        for error in cases {
            #expect(error.errorDescription != nil, "errorDescription should not be nil for \(error)")
            #expect(!error.errorDescription!.isEmpty, "errorDescription should not be empty for \(error)")
        }
    }

    // MARK: - ErrorSeverity Tests

    @Test("ErrorSeverity has all four levels")
    func errorSeverityHasAllLevels() {
        let low = ErrorSeverity.low
        let medium = ErrorSeverity.medium
        let high = ErrorSeverity.high
        let critical = ErrorSeverity.critical

        #expect(low != medium)
        #expect(high != critical)
    }
}
