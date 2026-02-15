//
//  TopMerchantsCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct TopMerchantsCard: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @State private var showAllMerchants = false

    private let displayLimit = 10

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(String(localized: "analytics.topMerchants"))
                    .font(.headline)
                Spacer()
                if !viewModel.topMerchants.isEmpty {
                    Button {
                        showAllMerchants = true
                    } label: {
                        Text(String(localized: "common.all"))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            if viewModel.topMerchants.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "storefront")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(String(localized: "analytics.noData"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(String(localized: "analytics.addTransactionsForAnalysis"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
            } else {
                // Merchants list
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.topMerchants.prefix(displayLimit).enumerated()), id: \.element.id) { index, merchant in
                        MerchantRow(
                            rank: index + 1,
                            merchant: merchant,
                            viewModel: viewModel
                        )

                        if index < min(displayLimit, viewModel.topMerchants.count) - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }

                if viewModel.topMerchants.count > displayLimit {
                    Button {
                        showAllMerchants = true
                    } label: {
                        HStack {
                            Text(String(localized: "common.showMore \(viewModel.topMerchants.count - displayLimit)"))
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showAllMerchants) {
            AllMerchantsSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Merchant Row

struct MerchantRow: View {
    let rank: Int
    let merchant: MerchantSpending
    let viewModel: AnalyticsViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(rankColor)
            }

            // Merchant info
            VStack(alignment: .leading, spacing: 4) {
                Text(merchant.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(String(localized: "analytics.transactionCount \(merchant.transactionCount)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            Text(viewModel.formatAmount(merchant.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .accentColor
        }
    }
}

// MARK: - All Merchants Sheet

struct AllMerchantsSheet: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredMerchants.indices, id: \.self) { index in
                    MerchantRow(
                        rank: index + 1,
                        merchant: filteredMerchants[index],
                        viewModel: viewModel
                    )
                }
            }
            .navigationTitle(String(localized: "analytics.allMerchants"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: String(localized: "search.merchants"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredMerchants: [MerchantSpending] {
        if searchText.isEmpty {
            return viewModel.topMerchants
        } else {
            return viewModel.topMerchants.filter {
                $0.merchantName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
