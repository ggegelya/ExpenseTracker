//
//  TransactionListView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var viewModel: TransactionViewModel
    @State private var showFilters = false
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    // Month summary
                    if !viewModel.transactions.isEmpty && !viewModel.isBulkEditMode {
                        MonthSummaryCard(
                            expenses: viewModel.currentMonthTotal,
                            income: viewModel.currentMonthIncome
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    // Active filters indicator
                    if viewModel.hasActiveFilters && !viewModel.isBulkEditMode {
                        Section {
                            HStack {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Активні фільтри")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Очистити") {
                                    viewModel.clearAllFilters()
                                }
                                .font(.caption)
                            }
                        }
                    }

                    // Transactions grouped by date
                    ForEach(groupedTransactions, id: \.key) { date, transactions in
                        Section {
                            ForEach(transactions) { transaction in
                                TransactionRowWithSelection(
                                    transaction: transaction,
                                    isSelected: viewModel.selectedTransactionIds.contains(transaction.id),
                                    isBulkEditMode: viewModel.isBulkEditMode
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.isBulkEditMode {
                                        viewModel.toggleTransactionSelection(transaction.id)
                                    } else {
                                        selectedTransaction = transaction
                                        showTransactionDetail = true
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !viewModel.isBulkEditMode {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteTransaction(transaction)
                                            }
                                        } label: {
                                            Label("Видалити", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text(date, style: .date)
                                .font(.headline)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())

                // Bulk Actions Bar
                if viewModel.isBulkEditMode {
                    BulkActionsBar()
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle("Транзакції")
            .searchable(
                text: $viewModel.searchText,
                prompt: "Пошук за описом, категорією"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Filter button with badge
                        Button {
                            showFilters.toggle()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .foregroundColor(viewModel.hasActiveFilters ? .accentColor : .primary)

                                if viewModel.hasActiveFilters {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }

                        // Bulk edit toggle
                        Button {
                            withAnimation {
                                viewModel.isBulkEditMode.toggle()
                                if !viewModel.isBulkEditMode {
                                    viewModel.deselectAllTransactions()
                                }
                            }
                        } label: {
                            Image(systemName: viewModel.isBulkEditMode ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(viewModel.isBulkEditMode ? .accentColor : .primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterView()
            }
            .sheet(isPresented: $showTransactionDetail) {
                if let transaction = selectedTransaction {
                    TransactionDetailView(transaction: transaction)
                }
            }
            .overlay {
                if viewModel.filteredTransactions.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "tray",
                        title: "Транзакцій не знайдено",
                        subtitle: viewModel.hasActiveFilters ?
                            "Спробуйте змінити фільтри або пошуковий запит" :
                            "Додайте свою першу транзакцію"
                    )
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
        }
    }

    private var groupedTransactions: [(key: Date, value: [Transaction])] {
        let grouped = Dictionary(grouping: viewModel.filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.transactionDate)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

// MARK: - Transaction Row with Selection

struct TransactionRowWithSelection: View {
    let transaction: Transaction
    let isSelected: Bool
    let isBulkEditMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox in bulk edit mode
            if isBulkEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .gray)
                    .font(.title3)
            }

            // Transaction row content
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let category = transaction.category {
                        Text("#\(category.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(transaction.transactionDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(transaction.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected && isBulkEditMode ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(6)
    }
}
