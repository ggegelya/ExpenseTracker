//
//  CoachMarkManager.swift
//  ExpenseTracker
//

import Foundation
import Combine

/// Manages one-time contextual coach marks with UserDefaults persistence.
/// Each coach mark fires once and never again.
@MainActor
final class CoachMarkManager: ObservableObject, CoachMarkManagerProtocol {
    /// Currently active (visible) coach marks.
    @Published private(set) var activeMarks: Set<CoachMarkID> = []

    private let defaults: UserDefaults
    private let suppressInTests: Bool

    init(defaults: UserDefaults = .standard, suppressInTests: Bool = true) {
        self.defaults = defaults
        self.suppressInTests = suppressInTests
    }

    func shouldShow(_ id: CoachMarkID) -> Bool {
        activeMarks.contains(id) && !hasBeenShown(id)
    }

    func activate(_ id: CoachMarkID) {
        // Suppress during UI tests to avoid interference
        if suppressInTests && TestingConfiguration.isRunningTests { return }
        // Don't activate if already shown
        guard !hasBeenShown(id) else { return }
        activeMarks.insert(id)
    }

    func deactivate(_ id: CoachMarkID) {
        activeMarks.remove(id)
        // Persist so it never shows again
        defaults.set(true, forKey: UserDefaultsKeys.coachMarkShown(id))
    }

    func hasBeenShown(_ id: CoachMarkID) -> Bool {
        defaults.bool(forKey: UserDefaultsKeys.coachMarkShown(id))
    }
}
