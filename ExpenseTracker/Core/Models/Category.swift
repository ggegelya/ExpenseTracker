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
    
    static let defaults = [
        Category(id: UUID(), name: "продукти", icon: "cart.fill", colorHex: "#4CAF50"),
        Category(id: UUID(), name: "таксі", icon: "car.fill", colorHex: "#FFC107"),
        Category(id: UUID(), name: "підписки", icon: "repeat", colorHex: "#9C27B0"),
        Category(id: UUID(), name: "комуналка", icon: "house.fill", colorHex: "#2196F3"),
        Category(id: UUID(), name: "аптека", icon: "cross.case.fill", colorHex: "#F44336"),
        Category(id: UUID(), name: "кафе", icon: "cup.and.saucer.fill", colorHex: "#FF9800"),
        Category(id: UUID(), name: "одяг", icon: "tshirt.fill", colorHex: "#E91E63"),
        Category(id: UUID(), name: "розваги", icon: "gamecontroller.fill", colorHex: "#00BCD4"),
        Category(id: UUID(), name: "транспорт", icon: "bus.fill", colorHex: "#795548"),
        Category(id: UUID(), name: "подарунки", icon: "gift.fill", colorHex: "#FF5722"),
        Category(id: UUID(), name: "навчання", icon: "book.fill", colorHex: "#3F51B5"),
        Category(id: UUID(), name: "спорт", icon: "figure.run", colorHex: "#4CAF50"),
        Category(id: UUID(), name: "краса", icon: "sparkles", colorHex: "#E91E63"),
        Category(id: UUID(), name: "техніка", icon: "desktopcomputer", colorHex: "#607D8B"),
        Category(id: UUID(), name: "інше", icon: "ellipsis.circle.fill", colorHex: "#9E9E9E")
    ]
    
}

