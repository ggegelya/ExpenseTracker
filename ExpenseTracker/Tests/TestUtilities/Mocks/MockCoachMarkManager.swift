//
//  MockCoachMarkManager.swift
//  ExpenseTracker
//
//  Mock implementation of CoachMarkManagerProtocol for testing
//

import Foundation
@testable import ExpenseTracker

@MainActor
final class MockCoachMarkManager: CoachMarkManagerProtocol {
    private(set) var activatedMarks: [CoachMarkID] = []
    private(set) var deactivatedMarks: [CoachMarkID] = []
    private var shownMarks: Set<CoachMarkID> = []
    private var activeMarks: Set<CoachMarkID> = []

    func shouldShow(_ id: CoachMarkID) -> Bool {
        activeMarks.contains(id) && !shownMarks.contains(id)
    }

    func activate(_ id: CoachMarkID) {
        activatedMarks.append(id)
        if !shownMarks.contains(id) {
            activeMarks.insert(id)
        }
    }

    func deactivate(_ id: CoachMarkID) {
        deactivatedMarks.append(id)
        activeMarks.remove(id)
        shownMarks.insert(id)
    }

    func hasBeenShown(_ id: CoachMarkID) -> Bool {
        shownMarks.contains(id)
    }

    // MARK: - Test Helpers

    func wasActivated(_ id: CoachMarkID) -> Bool {
        activatedMarks.contains(id)
    }

    func wasDeactivated(_ id: CoachMarkID) -> Bool {
        deactivatedMarks.contains(id)
    }

    func activationCount(for id: CoachMarkID) -> Int {
        activatedMarks.filter { $0 == id }.count
    }

    func reset() {
        activatedMarks.removeAll()
        deactivatedMarks.removeAll()
        shownMarks.removeAll()
        activeMarks.removeAll()
    }
}
