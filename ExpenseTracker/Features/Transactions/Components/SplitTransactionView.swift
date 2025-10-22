//
//  SplitTransactionView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct SplitTransactionView: View {
    let originalTransaction: Transaction
    let onSave: ([SplitItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransactionViewModel

    @State private var splitItems: [SplitItem] = []
    @State private var categoryPickerContext: CategoryPickerContext?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    struct CategoryPickerContext: Identifiable {
        let id = UUID()
        let index: Int
        let currentCategory: Category?
    }

    var totalSplitAmount: Decimal {
        splitItems.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var remainingAmount: Decimal {
        originalTransaction.amount - totalSplitAmount
    }

    var isValid: Bool {
        guard !splitItems.isEmpty else { return false }
        guard splitItems.allSatisfy({ $0.category != nil && $0.amount > 0 }) else { return false }
        return abs((remainingAmount as NSDecimalNumber).doubleValue) < 0.01 // Allow for floating point errors
    }

    var validationError: String? {
        if splitItems.isEmpty {
            return "Додайте хоча б один розділ"
        }

        for (index, item) in splitItems.enumerated() {
            if item.category == nil {
                return "Розділ \(index + 1): оберіть категорію"
            }
            if item.amount <= 0 {
                return "Розділ \(index + 1): сума повинна бути більше 0"
            }
        }

        if abs((remainingAmount as NSDecimalNumber).doubleValue) >= 0.01 {
            if remainingAmount > 0 {
                return "Розподілено недостатньо: залишилось ₴\(formatDecimal(remainingAmount))"
            } else {
                return "Розподілено забагато: перевищення на ₴\(formatDecimal(abs(remainingAmount)))"
            }
        }

        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                mainContent
            }
            .navigationTitle("Розділити транзакцію")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Скасувати") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(item: $categoryPickerContext) { context in
                SplitCategoryPickerSheet(
                    selectedCategory: context.currentCategory,
                    onSelect: { category in
                        splitItems[context.index].category = category
                        categoryPickerContext = nil
                    }
                )
                .environmentObject(viewModel)
            }
            .alert("Помилка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                loadInitialSplits()
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
                    // Original Transaction Card
                    originalTransactionCard

                    // Split Allocation Visualization
                    splitAllocationView

                    // Split Items List
                    VStack(spacing: 12) {
                        HStack {
                            Text("Розділи")
                                .font(.headline)
                            Spacer()
                            Text("\(splitItems.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }

                        ForEach(Array(splitItems.enumerated()), id: \.element.id) { index, item in
                            SplitItemRow(
                                splitItem: Binding(
                                    get: { splitItems[index] },
                                    set: { splitItems[index] = $0 }
                                ),
                                totalAmount: originalTransaction.amount,
                                onDelete: {
                                    withAnimation {
                                        let _ = splitItems.remove(at: index)
                                    }
                                },
                                onCategorySelect: {
                                    categoryPickerContext = CategoryPickerContext(
                                        index: index,
                                        currentCategory: splitItems[index].category
                                    )
                                }
                            )
                        }

                        // Add Split Button
                        Button {
                            withAnimation {
                                let newSplit = SplitItem(
                                    amount: remainingAmount > 0 ? remainingAmount : 0,
                                    category: nil,
                                    description: ""
                                )
                                splitItems.append(newSplit)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Додати розділ")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    // Validation Error
                    if let error = validationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Action Buttons
                    actionButtons
                }
                .padding(.vertical)
    }

    // MARK: - Original Transaction Card
    private var originalTransactionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Оригінальна транзакція")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(originalTransaction.description)
                            .font(.body)
                            .fontWeight(.medium)

                        if let category = originalTransaction.category {
                            Text("#\(category.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(formatDate(originalTransaction.transactionDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formatAmount(originalTransaction.amount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(originalTransaction.type == .expense ? .red : .green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    // MARK: - Split Allocation View
    private var splitAllocationView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Розподіл")
                    .font(.headline)
                Spacer()

                HStack(spacing: 4) {
                    Text("Залишок:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(remainingAmount))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(abs((remainingAmount as NSDecimalNumber).doubleValue) < 0.01 ? .green : .orange)
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 24)

                    // Allocated segments
                    HStack(spacing: 0) {
                        ForEach(splitItems) { item in
                            if let category = item.category, item.amount > 0 {
                                let percentage = (item.amount as NSDecimalNumber).doubleValue / (originalTransaction.amount as NSDecimalNumber).doubleValue
                                let width = geometry.size.width * CGFloat(percentage)

                                Rectangle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: width, height: 24)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(height: 24)

            // Legend
            if !splitItems.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(splitItems.filter { $0.category != nil }) { item in
                        if let category = item.category {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(category.name)
                                    .font(.caption2)
                                Text("₴\(formatDecimal(item.amount))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                saveSplit()
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Зберегти розділ")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid || isSaving)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Actions
    private func loadInitialSplits() {
        if let existingSplits = originalTransaction.splitTransactions, !existingSplits.isEmpty {
            // Load existing splits
            splitItems = existingSplits.map { split in
                SplitItem(
                    id: split.id,
                    amount: split.amount,
                    category: split.category,
                    description: split.description
                )
            }
        } else {
            // Create initial split with remaining amount
            splitItems = []
        }
    }

    private func saveSplit() {
        guard isValid else {
            errorMessage = validationError ?? "Некоректні дані"
            showError = true
            return
        }

        isSaving = true

        // Call the save handler
        onSave(splitItems)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
            dismiss()
        }
    }

    // MARK: - Formatters
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
    }

    private func formatDecimal(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter.string(from: date)
    }
}

// MARK: - Category Picker Sheet
private struct SplitCategoryPickerSheet: View {
    let selectedCategory: Category?
    let onSelect: (Category) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransactionViewModel
    @State private var searchText = ""

    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return viewModel.categories
        }
        return viewModel.categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.colorHex))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: category.colorHex).opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(category.name.capitalized)
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Оберіть категорію")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Пошук категорій")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
