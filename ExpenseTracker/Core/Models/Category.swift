//
//  Category.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import Foundation

struct Category: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String

    var displayName: String {
        let key = "category.\(name)"
        let localized = String(localized: String.LocalizationValue(key))
        // If String(localized:) returns the key itself, this is a user-created category — use name directly
        return localized == key ? name : localized
    }

    static let defaults = [
        Category(id: UUID(), name: "groceries", icon: "cart.fill", colorHex: "#4CAF50"),
        Category(id: UUID(), name: "taxi", icon: "car.fill", colorHex: "#FFC107"),
        Category(id: UUID(), name: "subscriptions", icon: "repeat", colorHex: "#9C27B0"),
        Category(id: UUID(), name: "utilities", icon: "house.fill", colorHex: "#2196F3"),
        Category(id: UUID(), name: "pharmacy", icon: "cross.case.fill", colorHex: "#F44336"),
        Category(id: UUID(), name: "cafe", icon: "cup.and.saucer.fill", colorHex: "#FF9800"),
        Category(id: UUID(), name: "clothing", icon: "tshirt.fill", colorHex: "#E91E63"),
        Category(id: UUID(), name: "entertainment", icon: "gamecontroller.fill", colorHex: "#00BCD4"),
        Category(id: UUID(), name: "transport", icon: "bus.fill", colorHex: "#795548"),
        Category(id: UUID(), name: "gifts", icon: "gift.fill", colorHex: "#FF5722"),
        Category(id: UUID(), name: "education", icon: "book.fill", colorHex: "#3F51B5"),
        Category(id: UUID(), name: "sports", icon: "figure.run", colorHex: "#4CAF50"),
        Category(id: UUID(), name: "beauty", icon: "sparkles", colorHex: "#E91E63"),
        Category(id: UUID(), name: "electronics", icon: "desktopcomputer", colorHex: "#607D8B"),
        Category(id: UUID(), name: "other", icon: "ellipsis.circle.fill", colorHex: "#9E9E9E")
    ]

}
