//
//  Color+Hex.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 22.10.2025.
//

import SwiftUI
import UIKit

private final class ColorCache {
    static let shared = ColorCache()

    private let cache = NSCache<NSString, UIColor>()
    private let lock = NSLock()

    func color(for hex: String) -> UIColor {
        let key = hex as NSString

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let normalizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: normalizedHex).scanHexInt64(&int)

        let color: UIColor
        switch normalizedHex.count {
        case 3:
            // RGB (12-bit)
            let r = CGFloat((int >> 8) * 17) / 255
            let g = CGFloat((int >> 4 & 0xF) * 17) / 255
            let b = CGFloat((int & 0xF) * 17) / 255
            color = UIColor(red: r, green: g, blue: b, alpha: 1)
        case 6:
            // RGB (24-bit)
            let r = CGFloat((int >> 16) & 0xFF) / 255
            let g = CGFloat((int >> 8) & 0xFF) / 255
            let b = CGFloat(int & 0xFF) / 255
            color = UIColor(red: r, green: g, blue: b, alpha: 1)
        case 8:
            // ARGB (32-bit)
            let a = CGFloat((int >> 24) & 0xFF) / 255
            let r = CGFloat((int >> 16) & 0xFF) / 255
            let g = CGFloat((int >> 8) & 0xFF) / 255
            let b = CGFloat(int & 0xFF) / 255
            color = UIColor(red: r, green: g, blue: b, alpha: a)
        default:
            color = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        }

        cache.setObject(color, forKey: key)
        return color
    }
}

extension Color {
    init(hex: String) {
        self.init(ColorCache.shared.color(for: hex))
    }
}
