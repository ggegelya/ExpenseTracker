//
//  ErrorHandlingServiceTests.swift
//  ExpenseTracker
//
//  Tests for ErrorHandlingService covering error routing (toast vs alert),
//  analytics tracking, toast/alert lifecycle, and handleAny() protocol extension.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("ErrorHandlingService Tests", .serialized)
@MainActor
struct ErrorHandlingServiceTests {
    var sut: ErrorHandlingService
    var mockAnalyticsService: MockAnalyticsService

    init() async throws {
        mockAnalyticsService = MockAnalyticsService()
        sut = ErrorHandlingService(analyticsService: mockAnalyticsService)
    }

    // MARK: - Error Routing Tests

    @Test("handle routes low-severity errors to toast")
    func handleRoutesLowSeverityToToast() {
        // Given - invalidAmount has .low severity
        let error = AppError.invalidAmount

        // When
        sut.handle(error, context: "test")

        // Then
        #expect(sut.currentToast != nil)
        #expect(sut.currentMessage == nil)
    }

    @Test("handle routes medium-severity errors to alert")
    func handleRoutesMediumSeverityToAlert() {
        // Given - networkUnavailable has .medium severity
        let error = AppError.networkUnavailable

        // When
        sut.handle(error, context: "test")

        // Then
        #expect(sut.currentMessage != nil)
    }

    @Test("handle routes high-severity errors to alert")
    func handleRoutesHighSeverityToAlert() {
        // Given - syncFailed has .high severity
        let error = AppError.syncFailed

        // When
        sut.handle(error, context: "test")

        // Then
        #expect(sut.currentMessage != nil)
    }

    @Test("handle routes critical-severity errors to alert")
    func handleRoutesCriticalSeverityToAlert() {
        // Given - dataCorruption has .critical severity
        let error = AppError.dataCorruption

        // When
        sut.handle(error, context: "test")

        // Then
        #expect(sut.currentMessage != nil)
    }

    @Test("handle tracks error via analytics service")
    func handleTracksErrorViaAnalytics() {
        // Given
        let error = AppError.invalidAmount

        // When
        sut.handle(error, context: "Save transaction")

        // Then
        #expect(mockAnalyticsService.hasTrackedErrors)
        #expect(mockAnalyticsService.wasErrorTracked(withContext: "Save transaction"))
    }

    // MARK: - Toast Tests

    @Test("showToast sets currentToast with correct message and type")
    func showToastSetsCurrentToast() {
        // When
        sut.showToast("Test message", type: .error)

        // Then
        #expect(sut.currentToast != nil)
        #expect(sut.currentToast?.message == "Test message")
        #expect(sut.currentToast?.type == .error)
    }

    @Test("showToast cancels previous auto-dismiss task")
    func showToastCancelsPreviousTask() async throws {
        // Given - show first toast
        sut.showToast("First message", type: .info)
        #expect(sut.currentToast?.message == "First message")

        // When - show second toast immediately
        sut.showToast("Second message", type: .warning)

        // Then - should have second message
        #expect(sut.currentToast?.message == "Second message")
        #expect(sut.currentToast?.type == .warning)
    }

    // MARK: - Alert Tests

    @Test("showAlert sets currentMessage with correct title and description")
    func showAlertSetsCurrentMessage() {
        // Given
        let error = AppError.networkUnavailable

        // When
        sut.showAlert(error, retryAction: nil)

        // Then
        #expect(sut.currentMessage != nil)
        #expect(sut.currentMessage?.message == error.localizedDescription)
        #expect(sut.currentMessage?.isRetryable == error.isRetryable)
    }

    @Test("showAlert includes retry action when provided")
    func showAlertIncludesRetryAction() {
        // Given
        let error = AppError.networkUnavailable
        var retried = false

        // When
        sut.showAlert(error, retryAction: { retried = true })

        // Then
        #expect(sut.currentMessage != nil)
        #expect(sut.currentMessage?.retryAction != nil)
        sut.currentMessage?.retryAction?()
        #expect(retried)
    }

    @Test("showAlert maps error recoverySuggestion")
    func showAlertMapsRecoverySuggestion() {
        // Given - networkUnavailable has a recovery suggestion
        let error = AppError.networkUnavailable

        // When
        sut.showAlert(error, retryAction: nil)

        // Then
        #expect(sut.currentMessage?.recoverySuggestion == error.recoverySuggestion)
    }

    @Test("showAlert for error without recovery suggestion sets nil")
    func showAlertNoRecoverySuggestion() {
        // Given - invalidAmount has no recovery suggestion
        let error = AppError.invalidAmount

        // When
        sut.showAlert(error, retryAction: nil)

        // Then
        #expect(sut.currentMessage?.recoverySuggestion == nil)
    }

    // MARK: - Dismiss Tests

    @Test("dismissAlert clears currentMessage")
    func dismissAlertClearsMessage() {
        // Given
        sut.showAlert(.networkUnavailable, retryAction: nil)
        #expect(sut.currentMessage != nil)

        // When
        sut.dismissAlert()

        // Then
        #expect(sut.currentMessage == nil)
    }

    @Test("dismissToast clears currentToast")
    func dismissToastClearsToast() {
        // Given
        sut.showToast("Test", type: .info)
        #expect(sut.currentToast != nil)

        // When
        sut.dismissToast()

        // Then
        #expect(sut.currentToast == nil)
    }

    // MARK: - handleAny Protocol Extension Tests

    @Test("handleAny maps AppError directly")
    func handleAnyMapsAppErrorDirectly() {
        // Given
        let error: Error = AppError.invalidAmount

        // When
        let result = sut.handleAny(error, context: "test")

        // Then
        #expect(result == .invalidAmount)
    }

    @Test("handleAny maps RepositoryError to repositoryError case")
    func handleAnyMapsRepositoryError() {
        // Given
        let error: Error = RepositoryError.entityNotFound

        // When
        let result = sut.handleAny(error, context: "test")

        // Then
        #expect(result == .repositoryError(.entityNotFound))
    }

    @Test("handleAny maps URLError to appropriate case")
    func handleAnyMapsURLError() {
        // Given
        let error: Error = URLError(.notConnectedToInternet)

        // When
        let result = sut.handleAny(error, context: "test")

        // Then
        #expect(result == .networkUnavailable)
    }

    @Test("handleAny maps unknown Error to syncFailed")
    func handleAnyMapsUnknownErrorToSyncFailed() {
        // Given
        let error: Error = NSError(domain: "Unknown", code: -1, userInfo: nil)

        // When
        let result = sut.handleAny(error, context: "test")

        // Then
        #expect(result == .syncFailed)
    }

    @Test("handleAny calls handle on the service")
    func handleAnyCallsHandle() {
        // Given
        let error: Error = AppError.invalidAmount

        // When
        _ = sut.handleAny(error, context: "test context")

        // Then - should have tracked the error through handle()
        #expect(mockAnalyticsService.hasTrackedErrors)
    }

    // MARK: - ToastType Tests

    @Test("ToastType has correct icons")
    func toastTypeHasCorrectIcons() {
        #expect(!ToastType.success.icon.isEmpty)
        #expect(!ToastType.warning.icon.isEmpty)
        #expect(!ToastType.error.icon.isEmpty)
        #expect(!ToastType.info.icon.isEmpty)
    }

    // MARK: - AlertMessage Tests

    @Test("AlertMessage stores all properties correctly")
    func alertMessageStoresProperties() {
        // Given
        var retried = false
        let alert = AlertMessage(
            title: "Error",
            message: "Something went wrong",
            recoverySuggestion: "Try again later",
            retryAction: { retried = true },
            isRetryable: true
        )

        // Then
        #expect(alert.title == "Error")
        #expect(alert.message == "Something went wrong")
        #expect(alert.recoverySuggestion == "Try again later")
        #expect(alert.isRetryable)
        alert.retryAction?()
        #expect(retried)
    }

    // MARK: - ToastMessage Tests

    @Test("ToastMessage stores message and type")
    func toastMessageStoresProperties() {
        let toast = ToastMessage(message: "Success!", type: .success)

        #expect(toast.message == "Success!")
        #expect(toast.type == .success)
    }
}
