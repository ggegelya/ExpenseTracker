//
//  MockCategorizationService.swift
//  ExpenseTracker
//
//  Mock implementation of CategorizationServiceProtocol for testing
//

import Foundation

/// Mock implementation of CategorizationServiceProtocol for testing
/// Provides predictable categorization suggestions and tracks learning calls
@MainActor
final class MockCategorizationService: CategorizationServiceProtocol {

    // MARK: - Call Tracking

    struct SuggestCategoryCall {
        let description: String
        let merchantName: String?
        let timestamp: Date
    }

    struct LearnFromCorrectionCall {
        let description: String
        let merchantName: String?
        let correctCategory: Category
        let timestamp: Date
    }

    private(set) var suggestCategoryCalls: [SuggestCategoryCall] = []
    private(set) var learnFromCorrectionCalls: [LearnFromCorrectionCall] = []

    // MARK: - Configuration

    /// Default category to return when no specific rule matches
    var defaultCategory: Category?

    /// Default confidence level (0.0 - 1.0)
    var defaultConfidence: Float = 0.50

    /// Mapping of merchant names to categories with confidence levels
    private var merchantRules: [String: (category: Category?, confidence: Float)] = [:]

    /// Mapping of description patterns to categories with confidence levels
    private var descriptionRules: [String: (category: Category?, confidence: Float)] = [:]

    /// Result to return on next call (overrides all rules)
    var nextResult: (category: Category?, confidence: Float)?

    /// Whether to throw an error on next call
    var shouldThrowError: Bool = false
    var errorToThrow: Error = NSError(domain: "MockCategorizationService", code: -1)

    // MARK: - Initialization

    init() {
        setupDefaultRules()
    }

    /// Sets up default categorization rules based on common merchants
    private func setupDefaultRules() {
        let groceriesCategory = MockCategory.makeGroceries()
        let taxiCategory = MockCategory.makeTaxi()
        let cafeCategory = MockCategory.makeCafe()
        let entertainmentCategory = MockCategory.makeEntertainment()
        let healthCategory = MockCategory.makeHealth()
        let transportCategory = MockCategory.makeTransport()

        // Merchant-based rules
        setMerchantRule("Silpo", category: groceriesCategory, confidence: 0.95)
        setMerchantRule("ATB", category: groceriesCategory, confidence: 0.95)
        setMerchantRule("Uber", category: taxiCategory, confidence: 0.90)
        setMerchantRule("Bolt", category: taxiCategory, confidence: 0.90)
        setMerchantRule("Netflix", category: entertainmentCategory, confidence: 0.95)
        setMerchantRule("Spotify", category: entertainmentCategory, confidence: 0.95)
        setMerchantRule("McDonald's", category: cafeCategory, confidence: 0.85)
        setMerchantRule("KFC", category: cafeCategory, confidence: 0.85)

        // Description-based rules
        setDescriptionRule("продукти", category: groceriesCategory, confidence: 0.80)
        setDescriptionRule("таксі", category: taxiCategory, confidence: 0.80)
        setDescriptionRule("кафе", category: cafeCategory, confidence: 0.75)
        setDescriptionRule("аптека", category: healthCategory, confidence: 0.85)
        setDescriptionRule("транспорт", category: transportCategory, confidence: 0.75)
        setDescriptionRule("метро", category: transportCategory, confidence: 0.85)
    }

    // MARK: - Rule Configuration

    /// Sets a categorization rule for a specific merchant
    func setMerchantRule(_ merchantName: String, category: Category?, confidence: Float) {
        merchantRules[merchantName.lowercased()] = (category, confidence)
    }

    /// Sets a categorization rule for a description pattern
    func setDescriptionRule(_ pattern: String, category: Category?, confidence: Float) {
        descriptionRules[pattern.lowercased()] = (category, confidence)
    }

    /// Removes all custom rules
    func clearRules() {
        merchantRules.removeAll()
        descriptionRules.removeAll()
    }

    /// Resets to default rules
    func resetToDefaults() {
        clearRules()
        setupDefaultRules()
        suggestCategoryCalls.removeAll()
        learnFromCorrectionCalls.removeAll()
        nextResult = nil
        shouldThrowError = false
    }

    // MARK: - CategorizationServiceProtocol Implementation

    func suggestCategory(for description: String, merchantName: String?) async -> (category: Category?, confidence: Float) {
        // Record the call
        suggestCategoryCalls.append(SuggestCategoryCall(
            description: description,
            merchantName: merchantName,
            timestamp: Date()
        ))

        // Check for error injection
        if shouldThrowError {
            // Note: Protocol doesn't throw, so we return nil with 0 confidence
            return (nil, 0.0)
        }

        // Check for override result
        if let result = nextResult {
            nextResult = nil
            return result
        }

        // Check merchant rules first (highest priority)
        if let merchantName = merchantName,
           let rule = merchantRules[merchantName.lowercased()] {
            return rule
        }

        // Check description rules
        let descriptionLower = description.lowercased()
        for (pattern, rule) in descriptionRules {
            if descriptionLower.contains(pattern) {
                return rule
            }
        }

        // Return default if no rules matched
        return (defaultCategory, defaultConfidence)
    }

    func learnFromCorrection(description: String, merchantName: String?, correctCategory: Category) async {
        // Record the call
        learnFromCorrectionCalls.append(LearnFromCorrectionCall(
            description: description,
            merchantName: merchantName,
            correctCategory: correctCategory,
            timestamp: Date()
        ))

        // In a real implementation, this would update the ML model or rules
        // For the mock, we can optionally update our rules

        if let merchantName = merchantName {
            // Learn from merchant correction with high confidence
            setMerchantRule(merchantName, category: correctCategory, confidence: 0.90)
        } else {
            // Learn from description with medium confidence
            setDescriptionRule(description, category: correctCategory, confidence: 0.70)
        }
    }

    // MARK: - Test Convenience Methods

    /// Returns whether suggestCategory was called
    var wasCalled: Bool {
        !suggestCategoryCalls.isEmpty
    }

    /// Returns the number of times suggestCategory was called
    var callCount: Int {
        suggestCategoryCalls.count
    }

    /// Returns whether learning was called
    var wasLearningCalled: Bool {
        !learnFromCorrectionCalls.isEmpty
    }

    /// Returns the number of times learning was called
    var learningCallCount: Int {
        learnFromCorrectionCalls.count
    }

    /// Returns the last suggestion call parameters
    var lastSuggestionCall: SuggestCategoryCall? {
        suggestCategoryCalls.last
    }

    /// Returns the last learning call parameters
    var lastLearningCall: LearnFromCorrectionCall? {
        learnFromCorrectionCalls.last
    }

    /// Clears all call history
    func clearCallHistory() {
        suggestCategoryCalls.removeAll()
        learnFromCorrectionCalls.removeAll()
    }

    // MARK: - Preset Configurations

    /// Configures the service to always return a specific category with high confidence
    func alwaysReturnCategory(_ category: Category, confidence: Float = 0.95) {
        defaultCategory = category
        defaultConfidence = confidence
        clearRules()
    }

    /// Configures the service to return no category (low confidence)
    func alwaysReturnNoCategory() {
        defaultCategory = nil
        defaultConfidence = 0.0
        clearRules()
    }

    /// Configures the service to return a specific category only once
    func returnOnce(category: Category?, confidence: Float) {
        nextResult = (category, confidence)
    }

    /// Simulates high-confidence categorization for common merchants
    func useHighConfidenceMode() {
        clearRules()
        setupDefaultRules()

        // Boost all confidence levels to 0.95
        merchantRules = merchantRules.mapValues { (category, _) in
            (category, 0.95)
        }

        descriptionRules = descriptionRules.mapValues { (category, _) in
            (category, 0.90)
        }
    }

    /// Simulates low-confidence categorization (needs manual review)
    func useLowConfidenceMode() {
        defaultConfidence = 0.30
        merchantRules = merchantRules.mapValues { (category, _) in
            (category, 0.35)
        }
        descriptionRules = descriptionRules.mapValues { (category, _) in
            (category, 0.30)
        }
    }

    // MARK: - Verification Helpers

    /// Verifies that a specific merchant was categorized
    func wasMerchantCategorized(_ merchantName: String) -> Bool {
        suggestCategoryCalls.contains { call in
            call.merchantName?.lowercased() == merchantName.lowercased()
        }
    }

    /// Verifies that a specific description was categorized
    func wasDescriptionCategorized(_ description: String) -> Bool {
        suggestCategoryCalls.contains { call in
            call.description.lowercased().contains(description.lowercased())
        }
    }

    /// Verifies that learning was performed for a specific category
    func wasLearningPerformed(for category: Category) -> Bool {
        learnFromCorrectionCalls.contains { call in
            call.correctCategory.id == category.id
        }
    }

    /// Returns all suggestions made for a specific merchant
    func suggestions(forMerchant merchantName: String) -> [SuggestCategoryCall] {
        suggestCategoryCalls.filter { call in
            call.merchantName?.lowercased() == merchantName.lowercased()
        }
    }

    /// Returns all learning corrections for a specific category
    func learningCorrections(for category: Category) -> [LearnFromCorrectionCall] {
        learnFromCorrectionCalls.filter { call in
            call.correctCategory.id == category.id
        }
    }
}
