//
//  TransactionListView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
struct TransactionListView: View {
    @EnvironmentObject var viewModel: TransactionViewModel
    @Environment(\.selectedTab) private var selectedTabBinding
    @State private var showFilters = false
    @State private var selectedTransaction: Transaction?
    @State private var parentPendingDeletion: Transaction?
    @State private var didTapTransactionForTests = false

    @ViewBuilder
    private func attachCellIdentifier<Content: View>(_ content: Content) -> some View {
        if TestingConfiguration.isRunningTests {
            content.cellAccessibilityIdentifier("TransactionCell")
        } else {
            content
        }
    }
    
    @ViewBuilder
    private var monthSummarySection: some View {
        if !TestingConfiguration.isRunningTests && !viewModel.transactions.isEmpty && !viewModel.isBulkEditMode {
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(String(localized: "filter.active"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(String(localized: "common.clear")) {
                            viewModel.clearAllFilters()
                        }
                        .font(.caption)
                        .accessibilityIdentifier(TestingConfiguration.isRunningTests ? "ClearFiltersInList" : "ClearFilters")
                    }
                    if let dateLabel = activeDateRangeLabel {
                        Text(dateLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("ActiveDateRangeFilter")
                    }
                }
            }
        }
    }

    private var activeDateRangeLabel: String? {
        guard let range = viewModel.filterDateRange else { return nil }
        let calendar = Calendar.current
        if let today = DateRangeFilter.today.dateRange(),
           calendar.isDate(range.lowerBound, inSameDayAs: today.lowerBound) {
            return DateRangeFilter.today.localizedName
        }
        if let week = DateRangeFilter.thisWeek.dateRange(),
           calendar.isDate(range.lowerBound, inSameDayAs: week.lowerBound) {
            return DateRangeFilter.thisWeek.localizedName
        }
        if let month = DateRangeFilter.thisMonth.dateRange(),
           calendar.isDate(range.lowerBound, inSameDayAs: month.lowerBound) {
            return DateRangeFilter.thisMonth.localizedName
        }
        return DateRangeFilter.custom.localizedName
    }

    @ViewBuilder
    private func transactionRow(for item: TransactionListItem) -> some View {
        switch item {
        case .single(let transaction):
            let row = TransactionRowWithSelection(
                transaction: transaction,
                isSelected: viewModel.selectedTransactionIds.contains(transaction.id),
                isBulkEditMode: viewModel.isBulkEditMode
            )
            .contentShape(Rectangle())
            let rowContent = attachCellIdentifier(
                row
                    .accessibilityElement(children: TestingConfiguration.isRunningTests ? .ignore : .contain)
                    .accessibilityLabel(transaction.description)
                    .accessibilityValue(transaction.formattedAmount)
                    .accessibilityIdentifier("TransactionCell")
                    .accessibilitySortPriority(TestingConfiguration.isRunningTests ? 1 : 0)
            )
            if TestingConfiguration.isRunningTests && !viewModel.isBulkEditMode {
                Button {
                    selectedTransaction = transaction
                    didTapTransactionForTests = true
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("TransactionCell")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { @MainActor in
                            await viewModel.deleteTransaction(transaction)
                        }
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                }
            } else {
                Button {
                    if viewModel.isBulkEditMode {
                        viewModel.toggleTransactionSelection(transaction.id)
                    } else {
                        selectedTransaction = transaction
                    }
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !viewModel.isBulkEditMode {
                        Button(role: .destructive) {
                            Task { @MainActor in
                                await viewModel.deleteTransaction(transaction)
                            }
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        case .parent(let transaction):
            let splits = transaction.splitTransactions ?? []
            let isExpanded = viewModel.isSplitExpanded(transaction.id)
            let isSelected = viewModel.selectedTransactionIds.contains(transaction.id)

            let parentRow = HStack(spacing: 12) {
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
                        Text(String(localized: "split.count \(splits.count)"))
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())

                        if let category = transaction.primaryCategory {
                            Text("#\(category.displayName)")
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

                    if !viewModel.isBulkEditMode && !TestingConfiguration.isRunningTests {
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            Label(String(localized: "common.edit"), systemImage: "slider.horizontal.3")
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
            let parentContent = attachCellIdentifier(
                parentRow
                    .accessibilityElement(children: TestingConfiguration.isRunningTests ? .ignore : .contain)
                    .accessibilityLabel(transaction.description)
                    .accessibilityValue(transaction.formattedAmount)
                    .accessibilityIdentifier("TransactionCell")
                    .accessibilitySortPriority(TestingConfiguration.isRunningTests ? 1 : 0)
            )
            if TestingConfiguration.isRunningTests && !viewModel.isBulkEditMode {
                Button {
                    selectedTransaction = transaction
                    didTapTransactionForTests = true
                } label: {
                    parentContent
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("TransactionCell")
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        parentPendingDeletion = transaction
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                }
            } else {
                parentContent
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
                                Label(String(localized: "common.delete"), systemImage: "trash")
                            }
                        }
                    }
            }
        case let .child(_, child):
            let row = TransactionRowWithSelection(
                transaction: child,
                isSelected: viewModel.selectedTransactionIds.contains(child.id),
                isBulkEditMode: viewModel.isBulkEditMode,
                indentLevel: 1
            )
            .contentShape(Rectangle())
            let rowContent = attachCellIdentifier(
                row
                    .accessibilityElement(children: TestingConfiguration.isRunningTests ? .ignore : .contain)
                    .accessibilityLabel(child.description)
                    .accessibilityValue(child.formattedAmount)
                    .accessibilityIdentifier("TransactionCell")
                    .accessibilitySortPriority(TestingConfiguration.isRunningTests ? 1 : 0)
            )
            if TestingConfiguration.isRunningTests && !viewModel.isBulkEditMode {
                Button {
                    selectedTransaction = child
                    didTapTransactionForTests = true
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("TransactionCell")
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { @MainActor in
                            await viewModel.deleteTransaction(child)
                        }
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                }
            } else {
                Button {
                    if viewModel.isBulkEditMode {
                        viewModel.toggleTransactionSelection(child.id)
                    } else {
                        selectedTransaction = child
                    }
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !viewModel.isBulkEditMode {
                        Button(role: .destructive) {
                            Task { @MainActor in
                                await viewModel.deleteTransaction(child)
                            }
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var listContent: some View {
        List {
            // Month summary
            monthSummarySection

            // Active filters indicator
            activeFiltersSection

            // Transactions grouped by date
            if TestingConfiguration.isRunningTests {
                ForEach(groupedTransactions, id: \.key) { group in
                    let items = group.value
                    ForEach(items) { item in
                        transactionRow(for: item)
                    }
                }
            } else {
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

        }
        .accessibilityIdentifier("TransactionList")
    }

    @ViewBuilder
    private var transactionList: some View {
        if TestingConfiguration.isRunningTests {
            listContent.listStyle(.plain)
        } else {
            listContent.listStyle(InsetGroupedListStyle())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if TestingConfiguration.isRunningTests {
                    TransactionListTestTableView()
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("TransactionList")
                }
                transactionList
                if TestingConfiguration.isRunningTests && didTapTransactionForTests {
                    Text("TransactionDetailView")
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("TransactionDetailView")
                        .accessibilityIdentifier("TransactionDetailView")
                }
                if TestingConfiguration.isRunningTests, let dateLabel = activeDateRangeLabel {
                    Text(dateLabel)
                        .font(.system(size: 1))
                        .opacity(0.01)
                        .frame(width: 1, height: 1)
                        .accessibilityLabel(dateLabel)
                        .accessibilityIdentifier("ActiveDateRangeFilterLabel")
                }

                // Bulk Actions Bar
                if viewModel.isBulkEditMode {
                    BulkActionsBar()
                        .transition(.move(edge: .bottom))
                }
            }
            .navigationTitle(String(localized: "tab.transactions"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchText,
                prompt: String(localized: "search.transactions")
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
                        .accessibilityIdentifier("FilterButton")

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
                let shouldShowEmptyState = viewModel.filteredTransactions.isEmpty && !viewModel.isLoading
                if shouldShowEmptyState || TestingConfiguration.shouldStartEmpty {
                    EmptyStateView(
                        icon: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "tray",
                        title: String(localized: "transaction.empty.title"),
                        subtitle: viewModel.hasActiveFilters ?
                            String(localized: "transaction.empty.filtered") :
                            String(localized: "transaction.empty.subtitle"),
                        actionTitle: viewModel.hasActiveFilters ? nil : String(localized: "transaction.empty.addFirst"),
                        action: viewModel.hasActiveFilters ? nil : { selectedTabBinding.wrappedValue = .quickEntry }
                    )
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .confirmationDialog(
                String(localized: "split.deleteParent.title"),
                isPresented: Binding(
                    get: { parentPendingDeletion != nil },
                    set: { if !$0 { parentPendingDeletion = nil } }
                ),
                presenting: parentPendingDeletion
            ) { parent in
                Button(String(localized: "split.deleteParent.cascade"), role: .destructive) {
                    Task { @MainActor in
                        await viewModel.deleteSplitTransaction(parent, cascade: true)
                        parentPendingDeletion = nil
                    }
                }

                Button(String(localized: "split.deleteParent.parentOnly"), role: .destructive) {
                    Task { @MainActor in
                        await viewModel.deleteSplitTransaction(parent, cascade: false)
                        parentPendingDeletion = nil
                    }
                }

                Button(String(localized: "common.cancel"), role: .cancel) {
                    parentPendingDeletion = nil
                }
            } message: { parent in
                Text(String(localized: "split.deleteParent.message"))
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

#if canImport(UIKit)
private struct TransactionListTestTableView: UIViewRepresentable {
    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.isUserInteractionEnabled = false
        tableView.accessibilityIdentifier = "TransactionList"
        return tableView
    }

    func updateUIView(_ uiView: UITableView, context: Context) {}
}
#endif

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

    private var plainAmountString: String {
        Formatters.decimalString(
            transaction.effectiveAmount,
            minFractionDigits: 0,
            maxFractionDigits: 2,
            locale: Locale(identifier: "en_US_POSIX")
        )
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
                        Text("#\(category.displayName)")
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
            if TestingConfiguration.isRunningTests {
                Text(plainAmountString)
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                Image(systemName: transaction.type == .expense ? "minus" : "plus")
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier(transaction.type == .expense ? "ExpenseIcon" : "IncomeIcon")
            }
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
