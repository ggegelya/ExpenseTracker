//
//  Spacing.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 16.11.2025.
//

import SwiftUI

/// Standardized spacing system for consistent UI across the app
/// Based on QuickEntryView spacing analysis and hero layout patterns
enum Spacing {
    // MARK: - Stack Spacing (between elements within a group)

    /// Minimal spacing between tightly related elements (4pt)
    /// Example: Icon and text in a pill, small labels
    static let xxs: CGFloat = 4

    /// Tight spacing for related content (6pt)
    /// Example: Elements within a metadata pill
    static let xs: CGFloat = 6

    /// Standard spacing for grouped elements (8pt)
    /// Example: Pills in a row, list items
    static let sm: CGFloat = 8

    /// Medium spacing for sections (10pt)
    /// Example: Section internal spacing, form fields
    static let md: CGFloat = 10

    /// Default spacing for most content (12pt)
    /// Example: Between form rows, card elements
    static let base: CGFloat = 12

    /// Large spacing between sections (16pt)
    /// Example: Between list items, card padding
    static let lg: CGFloat = 16

    /// Extra large spacing for major sections (20pt)
    /// Example: Split view items, major content groups
    static let xl: CGFloat = 20

    /// Spacious section separation (24pt)
    /// Example: Hero layout sections, detail view sections
    static let xxl: CGFloat = 24

    /// Maximum section spacing (32pt)
    /// Example: Major content boundaries, top-level sections
    static let xxxl: CGFloat = 32

    /// Extra spacious for hero layouts (40pt)
    /// Example: Between hero element and action buttons
    static let hero: CGFloat = 40

    // MARK: - Padding (insets for containers)

    /// Minimal padding (4pt)
    static let paddingXXS: CGFloat = 4

    /// Small padding for compact elements (6pt)
    static let paddingXS: CGFloat = 6

    /// Standard padding for pills and chips (12pt horizontal, 6pt vertical)
    static let paddingSM: CGFloat = 12

    /// Default content padding (16pt)
    /// Example: Screen edges, card interiors
    static let paddingBase: CGFloat = 16

    /// Large padding for spacious layouts (20pt)
    /// Example: ScrollView content, major sections
    static let paddingLG: CGFloat = 20

    /// Extra large padding (24pt)
    static let paddingXL: CGFloat = 24

    // MARK: - Semantic Spacing (specific use cases)

    /// Spacing between hero element and metadata pills
    static let heroToMetadata: CGFloat = 8

    /// Spacing between metadata pills
    static let betweenPills: CGFloat = 8

    /// Spacing between pill rows
    static let betweenPillRows: CGFloat = 8

    /// Spacing between major sections in detail views
    static let betweenSections: CGFloat = 24

    /// Spacing between category and action buttons
    static let categoryToAction: CGFloat = 40

    /// Bottom padding with actions
    static let actionToBottom: CGFloat = 32

    /// Footer height spacing
    static let footer: CGFloat = 80

    // MARK: - List Spacing

    /// Spacing between list rows
    static let listRowSpacing: CGFloat = 16

    /// Spacing between list sections
    static let listSectionSpacing: CGFloat = 24

    // MARK: - Pill/Chip Dimensions

    /// Standard pill horizontal padding
    static let pillHorizontal: CGFloat = 12

    /// Standard pill vertical padding
    static let pillVertical: CGFloat = 6

    /// Corner radius for pills and small cards
    static let pillCornerRadius: CGFloat = 12

    /// Corner radius for standard cards
    static let cardCornerRadius: CGFloat = 8

    // MARK: - Helper Methods

    /// Returns spacing based on a multiplier
    /// - Parameter multiplier: Multiplier for base spacing
    /// - Returns: Calculated spacing
    static func custom(_ multiplier: CGFloat) -> CGFloat {
        base * multiplier
    }

    /// Returns padding edge insets for consistent container padding
    /// - Parameter value: Padding value to use
    /// - Returns: EdgeInsets with padding on all sides
    static func insets(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }

    /// Returns padding edge insets with different horizontal and vertical values
    /// - Parameters:
    ///   - horizontal: Horizontal padding
    ///   - vertical: Vertical padding
    /// - Returns: EdgeInsets with specified padding
    static func insets(horizontal: CGFloat, vertical: CGFloat) -> EdgeInsets {
        EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
