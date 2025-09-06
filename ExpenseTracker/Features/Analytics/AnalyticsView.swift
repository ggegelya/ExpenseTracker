//
//  AnalyticsView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var viewModel: TransactionViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month overview
                    MonthOverviewCard()
                    
                    // Category breakdown
                    CategoryBreakdownCard()
                    
                    // Spending trends
                    SpendingTrendsCard()
                    
                    // Top merchants
                    TopMerchantsCard()
                }
                .padding()
            }
            .navigationTitle("Аналітика")
        }
    }
}

struct MonthOverviewCard: View {
    var body: some View {
        Text("Month Overview")
    }
}

struct CategoryBreakdownCard: View {
    var body: some View {
        Text("Category Breakdown")
    }
}

struct SpendingTrendsCard: View {
    var body: some View {
        Text("Spending Trends")
    }
}

struct TopMerchantsCard: View {
    var body: some View {
        Text("Top Merchants")
    }
}
