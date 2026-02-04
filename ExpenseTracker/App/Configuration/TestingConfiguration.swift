//
//  TestingConfiguration.swift
//  ExpenseTracker
//
//  Created by Claude Code on 22.11.2025.
//

import Foundation

enum TestingConfiguration {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["IS_TESTING"] == "1" ||
        ProcessInfo.processInfo.arguments.contains("-UITesting") ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var shouldDisableAnimations: Bool {
        ProcessInfo.processInfo.environment["DISABLE_ANIMATIONS"] == "1" ||
        ProcessInfo.processInfo.arguments.contains("-DisableAnimations")
    }

    static var shouldResetAppState: Bool {
        ProcessInfo.processInfo.arguments.contains("-ResetAppState")
    }

    static var shouldUseMockData: Bool {
        ProcessInfo.processInfo.environment["MOCK_DATA_ENABLED"] == "1"
    }

    static var shouldStartEmpty: Bool {
        ProcessInfo.processInfo.environment["START_EMPTY"] == "1"
    }

    static var isCoreDataDebugEnabled: Bool {
        ProcessInfo.processInfo.environment["CORE_DATA_DEBUG"] == "1"
    }
}
