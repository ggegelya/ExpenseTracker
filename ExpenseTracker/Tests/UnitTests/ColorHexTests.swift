//
//  ColorHexTests.swift
//  ExpenseTracker
//
//  Tests for Color+Hex extension covering hex parsing (3/6/8 digit),
//  fallback behavior, caching, and edge cases.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import ExpenseTracker

@Suite("Color+Hex Tests")
struct ColorHexTests {

    // MARK: - Helper

    /// Extracts RGBA components from a Color created with hex
    private func components(for hex: String) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let uiColor = UIColor(Color(hex: hex))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func approxEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.02) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - 3-digit hex Tests

    @Test("3-digit hex '#F00' produces red")
    func threeDigitHexRed() {
        let c = components(for: "#F00")
        #expect(approxEqual(c.red, 1.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    @Test("3-digit hex '#0F0' produces green")
    func threeDigitHexGreen() {
        let c = components(for: "#0F0")
        #expect(approxEqual(c.red, 0.0))
        #expect(approxEqual(c.green, 1.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    // MARK: - 6-digit hex Tests

    @Test("6-digit hex '#FF0000' produces red")
    func sixDigitHexRed() {
        let c = components(for: "#FF0000")
        #expect(approxEqual(c.red, 1.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    @Test("6-digit hex '#00FF00' produces green")
    func sixDigitHexGreen() {
        let c = components(for: "#00FF00")
        #expect(approxEqual(c.red, 0.0))
        #expect(approxEqual(c.green, 1.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    @Test("6-digit hex '#0000FF' produces blue")
    func sixDigitHexBlue() {
        let c = components(for: "#0000FF")
        #expect(approxEqual(c.red, 0.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 1.0))
    }

    // MARK: - 8-digit hex Tests

    @Test("8-digit hex '#80FF0000' produces semi-transparent red")
    func eightDigitHexSemiTransparentRed() {
        let c = components(for: "#80FF0000")
        #expect(approxEqual(c.red, 1.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 0.0))
        #expect(approxEqual(c.alpha, 128.0 / 255.0, tolerance: 0.02))
    }

    // MARK: - Edge Cases

    @Test("Hex without '#' prefix works")
    func hexWithoutPrefix() {
        let c = components(for: "FF0000")
        #expect(approxEqual(c.red, 1.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    @Test("Invalid hex string produces black fallback")
    func invalidHexProducesBlack() {
        let c = components(for: "#ZZZZZZ")
        #expect(approxEqual(c.red, 0.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    @Test("Empty string produces black fallback")
    func emptyStringProducesBlack() {
        let c = components(for: "")
        #expect(approxEqual(c.red, 0.0))
        #expect(approxEqual(c.green, 0.0))
        #expect(approxEqual(c.blue, 0.0))
    }

    @Test("Thread safety: concurrent access doesn't crash")
    func threadSafetyConcurrentAccess() async throws {
        // Run multiple concurrent hex parsing operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let hex = String(format: "#%02X%02X%02X", i % 256, (i * 3) % 256, (i * 7) % 256)
                    _ = Color(hex: hex)
                }
            }
        }
        // If we reach here without crashing, the test passes
    }
}
