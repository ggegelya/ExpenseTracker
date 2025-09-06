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
    @State private var selectedTransactions: Set<Transaction.ID> = []
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            List(selection: $selectedTransactions) {
                // Month summary
                if !viewModel.transactions.isEmpty {
                    MonthSummaryCard(
                        expenses: viewModel.currentMonthTotal,
                        income: viewModel.currentMonthIncome
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // Transactions grouped by date
                ForEach(groupedTransactions, id: \.key) { date, transactions in
                    Section {
                        ForEach(transactions) { transaction in
                            TransactionRow(transaction: transaction)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteTransaction(transaction)
                                        }
                                    } label: {
                                        Label("Видалити", systemImage: "trash")
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
            .navigationTitle("Транзакції")
            .searchable(text: $viewModel.searchText, prompt: "Пошук транзакцій")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showFilters) {
                FilterView()
            }
            .overlay {
                if viewModel.filteredTransactions.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "Транзакцій не знайдено",
                        subtitle: "Спробуйте змінити фільтри або пошуковий запит"
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
