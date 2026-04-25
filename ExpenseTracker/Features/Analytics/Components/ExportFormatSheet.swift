//
//  ExportFormatSheet.swift
//  ExpenseTracker
//
//  Confirmation dialog that picks an export format before triggering
//  the system share sheet. Per the Banka design pack, this pattern is
//  also used for "delete transaction" and "clear draft" — keep the
//  modifier API generic so both reuses can adopt it.
//

import SwiftUI
import UIKit

extension View {
    /// Banka-style action sheet for picking an export format.
    ///
    /// Renders an iOS confirmation dialog with two primary buttons
    /// (PDF / CSV) plus Cancel. The `onPick` callback fires with the
    /// selected format; the parent is then responsible for generating
    /// the file and presenting the share sheet.
    func exportFormatSheet(
        isPresented: Binding<Bool>,
        onPick: @escaping (ExportFormat) -> Void
    ) -> some View {
        confirmationDialog(
            String(localized: "export.title"),
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: "export.format.pdf")) {
                onPick(.pdf)
            }
            Button(String(localized: "export.format.csv")) {
                onPick(.csv)
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "export.message"))
        }
    }
}

enum ExportFormat {
    case pdf
    case csv
}

/// Identifiable wrapper so `URL` can drive a `.sheet(item:)` presentation.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Native UIActivityViewController wrapper for sharing exported files.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
