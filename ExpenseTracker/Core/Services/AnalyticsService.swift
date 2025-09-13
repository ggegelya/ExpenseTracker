//
//  AnalyticsService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation

protocol AnalyticsServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent)
    func trackError(_ error: Error, context: String?)
}

enum AnalyticsEvent {
    case transactionAdded(amount: Decimal, category: String?)
    case transactionDeleted
    case accountConnected(bankName: String)
    case categoryCreated
    case exportCompleted(format: String)
}

final class AnalyticsService: AnalyticsServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent) {
        // In production, send to analytics service
        #if DEBUG
        print("Analytics: \(event)")
        #endif
    }
    
    func trackError(_ error: Error, context: String?) {
        // In production, send to error tracking service
        #if DEBUG
        print("Error tracked: \(error) - Context: \(context ?? "none")")
        #endif
    }
}
