//
//  EnvironmentTests.swift
//  ExpenseTracker
//
//  Tests for AppEnvironment configuration
//

import Testing
@testable import ExpenseTracker

@Suite("Environment Tests")
struct EnvironmentTests {

    @Test("Testing environment uses in-memory store")
    func testingUsesInMemoryStore() {
        #expect(AppEnvironment.testing.usesInMemoryStore == true)
    }

    @Test("Preview environment uses in-memory store")
    func previewUsesInMemoryStore() {
        #expect(AppEnvironment.preview.usesInMemoryStore == true)
    }

    @Test("Production environment uses persistent store")
    func productionUsesPersistentStore() {
        #expect(AppEnvironment.production.usesInMemoryStore == false)
    }

    @Test("Staging environment uses persistent store")
    func stagingUsesPersistentStore() {
        #expect(AppEnvironment.staging.usesInMemoryStore == false)
    }
}
