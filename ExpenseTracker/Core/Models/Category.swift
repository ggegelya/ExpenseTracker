//
//  Category.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import Foundation

struct Category: Codable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    
    static let defaults = [
        Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50"),
        Category(id: UUID(), name: "таксі", icon: "car.fill", colorHex: "#"),
        Category(id: UUID(), name: "підписки", icon: "repeat", colorHex: "#9C27B0"),
        Category(id: UUID(), name: "комуналка", icon: "house.fill", colorHex: "#2196F3"),
        Category(id: UUID(), name: "аптека", icon: "cross.case.fill", colorHex: "#F44336"),
        Category(id: UUID(), name: "інше", icon: "ellipsis.circle.fill", colorHex: "#607D8B")
    ]
    
}


