//
//  MonthSummaryCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct MonthSummaryCard: View {
    let expenses: Decimal
    let income: Decimal
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Поточний місяць")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Витрати")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(expenses))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.red)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("Доходи")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(income))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("Баланс")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(income - expenses))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor((income - expenses) >= 0 ? .green : .red)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let absAmount = abs(NSDecimalNumber(decimal: amount).doubleValue)
        if absAmount >= 1_000_000 {
            formatter.maximumFractionDigits = 1
            let millions = amount / 1_000_000
            return formatter.string(from: NSDecimalNumber(decimal: millions))?.replacingOccurrences(of: "₴", with: "M ₴") ?? "₴"
        } else {
            return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴"
        }
    }
}

// preview
#Preview {
    MonthSummaryCard(expenses: 0, income: 0)
        .padding()
}
