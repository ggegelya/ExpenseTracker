//
//  SuccessFeedbackView.swift
//  ExpenseTracker
//

import SwiftUI

struct SuccessFeedbackView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(String(localized: "toast.transactionAdded"))
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
}
