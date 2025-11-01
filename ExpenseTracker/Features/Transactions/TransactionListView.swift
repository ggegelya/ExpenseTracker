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
    @State private var parentPendingDeletion: Transaction?
    
    @ViewBuilder
    private var monthSummarySection: some View {
        if !viewModel.transactions.isEmpty && !viewModel.isBulkEditMode {
            MonthSummaryCard(
                expenses: viewModel.currentMonthTotal,
                income: viewModel.currentMonthIncome
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var activeFiltersSection: some View {
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
    }

    @ViewBuilder
    private func transactionRow(for item: TransactionListItem) -> some View {
        switch item {
        case .single(let transaction):
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
        case .parent(let transaction):
            let splits = transaction.splitTransactions ?? []
            let isExpanded = viewModel.isSplitExpanded(transaction.id)
            let isSelected = viewModel.selectedTransactionIds.contains(transaction.id)

            HStack(spacing: 12) {
                if viewModel.isBulkEditMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .gray)
                        .font(.title3)
                }

                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .foregroundColor(.blue)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(splits.count) розділів")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())

                        if let category = transaction.primaryCategory {
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

                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.type == .expense ? .red : .green)

                    if !viewModel.isBulkEditMode {
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            Label("Редагувати", systemImage: "slider.horizontal.3")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected && viewModel.isBulkEditMode ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.isBulkEditMode {
                    viewModel.toggleTransactionSelection(transaction.id)
                } else {
                    withAnimation {
                        viewModel.toggleSplitExpansion(transaction.id)
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !viewModel.isBulkEditMode {
                    Button(role: .destructive) {
                        parentPendingDeletion = transaction
                    } label: {
                        Label("Видалити", systemImage: "trash")
                    }
                }
            }
        case let .child(_, child):
            TransactionRowWithSelection(
                transaction: child,
                isSelected: viewModel.selectedTransactionIds.contains(child.id),
                isBulkEditMode: viewModel.isBulkEditMode,
                indentLevel: 1
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.isBulkEditMode {
                    viewModel.toggleTransactionSelection(child.id)
                } else {
                    selectedTransaction = child
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if !viewModel.isBulkEditMode {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteTransaction(child)
                        }
                    } label: {
                        Label("Видалити", systemImage: "trash")
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    // Month summary
                    monthSummarySection

                    // Active filters indicator
                    activeFiltersSection

                    // Transactions grouped by date
                    ForEach(groupedTransactions, id: \.key) { group in
                        let date = group.key
                        let items = group.value
                        Section {
                            ForEach(items) { item in
                                transactionRow(for: item)
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
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
                    .environmentObject(viewModel)
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
            .confirmationDialog(
                "Видалити сумарну транзакцію?",
                isPresented: Binding(
                    get: { parentPendingDeletion != nil },
                    set: { if !$0 { parentPendingDeletion = nil } }
                ),
                presenting: parentPendingDeletion
            ) { parent in
                Button("Видалити сумарну та всі розділи", role: .destructive) {
                    Task {
                        await viewModel.deleteSplitTransaction(parent, cascade: true)
                        parentPendingDeletion = nil
                    }
                }

                Button("Видалити лише сумарну", role: .destructive) {
                    Task {
                        await viewModel.deleteSplitTransaction(parent, cascade: false)
                        parentPendingDeletion = nil
                    }
                }

                Button("Скасувати", role: .cancel) {
                    parentPendingDeletion = nil
                }
            } message: { parent in
                Text("Видалення сумарної транзакції також може вплинути на пов'язані розділи. Оберіть дію.")
            }
        }
    }

    private var groupedTransactions: [(key: Date, value: [TransactionListItem])] {
        let grouped = Dictionary(grouping: viewModel.filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.transactionDate)
        }
        let transformed = grouped.map { (date, transactions) -> (Date, [TransactionListItem]) in
            let items = transactions.flatMap { transaction -> [TransactionListItem] in
                if transaction.isSplitParent, let splits = transaction.splitTransactions {
                    var rows: [TransactionListItem] = [.parent(transaction)]
                    if viewModel.isSplitExpanded(transaction.id) {
                        rows.append(contentsOf: splits.map { .child(parentId: transaction.id, $0) })
                    }
                    return rows
                } else {
                    return [.single(transaction)]
                }
            }
            return (date, items)
        }
        return transformed.sorted { $0.0 > $1.0 }
    }
}

// MARK: - Transaction Row with Selection

struct TransactionRowWithSelection: View {
    let transaction: Transaction
    let isSelected: Bool
    let isBulkEditMode: Bool
    let indentLevel: Int

    init(transaction: Transaction, isSelected: Bool, isBulkEditMode: Bool, indentLevel: Int = 0) {
        self.transaction = transaction
        self.isSelected = isSelected
        self.isBulkEditMode = isBulkEditMode
        self.indentLevel = indentLevel
    }

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
        .padding(.leading, CGFloat(indentLevel) * 20)
    }
}

private enum TransactionListItem: Identifiable {
    case single(Transaction)
    case parent(Transaction)
    case child(parentId: UUID, Transaction)

    var id: UUID {
        switch self {
        case .single(let transaction),
             .parent(let transaction),
             .child(_, let transaction):
            return transaction.id
        }
    }

    var transaction: Transaction {
        switch self {
        case .single(let transaction),
             .parent(let transaction),
             .child(_, let transaction):
            return transaction
        }
    }
}

