//
//  CoachMarkManagerProtocol.swift
//  ExpenseTracker
//

import Foundation

/// Protocol for managing one-time contextual coach marks.
@MainActor
protocol CoachMarkManagerProtocol: AnyObject {
    /// Whether a given coach mark should be shown (not yet shown + currently active).
    func shouldShow(_ id: CoachMarkID) -> Bool

    /// Activate a coach mark — it will show if not previously dismissed.
    func activate(_ id: CoachMarkID)

    /// Deactivate (dismiss) a coach mark and persist that it was shown.
    func deactivate(_ id: CoachMarkID)

    /// Whether a coach mark has already been shown (persisted).
    func hasBeenShown(_ id: CoachMarkID) -> Bool
}
