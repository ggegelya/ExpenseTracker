//
//  SplitTransactionView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct SplitTransactionView: View {
    let originalTransaction: Transaction
    let onSave: ([SplitItem], Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransactionViewModel // Safe: SwiftUI manages lifecycle

    @State private var splitItems: [SplitItem] = []
    @State private var categoryPickerContext: CategoryPickerContext?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var retainParent = true

    // MARK: - Performance Optimization: Cached Formatted Strings
    @State private var formattedBaseAmount: String = ""
    @State private var formattedTransactionDate: String = ""

    // MARK: - Memory Management: Task Tracking
    @State private var loadTask: Task<Void, Never>?

    struct CategoryPickerContext: Identifiable {
        let id = UUID()
        let index: Int
        let currentCategory: Category?
    }

    private var positiveSplits: [(item: SplitItem, category: Category)] {
        splitItems.compactMap { item in
            guard let category = item.category, item.amount > 0 else { return nil }
            return (item, category)
        }
    }

    private var baseAmount: Decimal {
        originalTransaction.isSplitParent ? originalTransaction.effectiveAmount : originalTransaction.amount
    }

    private var totalAmountDouble: Double {
        max((baseAmount as NSDecimalNumber).doubleValue, 0)
    }

    private var isRemainingBalanced: Bool {
        abs((remainingAmount as NSDecimalNumber).doubleValue) < 0.01
    }

    var totalSplitAmount: Decimal {
        splitItems.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var remainingAmount: Decimal {
        baseAmount - totalSplitAmount
    }

    var isValid: Bool {
        guard !splitItems.isEmpty else { return false }
        guard splitItems.allSatisfy({ $0.category != nil && $0.amount > 0 }) else { return false }
        return isRemainingBalanced
    }

    var validationError: String? {
        if splitItems.isEmpty {
            return String(localized: "split.addAtLeastOne")
        }

        for (index, item) in splitItems.enumerated() {
            if item.category == nil {
                return String(localized: "split.selectCategory \(index + 1)")
            }
            if item.amount <= 0 {
                return String(localized: "split.amountRequired \(index + 1)")
            }
        }

        if !isRemainingBalanced {
            if remainingAmount > 0 {
                return "\(String(localized: "split.underAllocated")): \(Formatters.currencyStringUAH(amount: remainingAmount))"
            } else {
                return "\(String(localized: "split.overAllocated")): \(Formatters.currencyStringUAH(amount: abs(remainingAmount)))"
            }
        }

        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                mainContent
            }
            .navigationTitle(String(localized: "split.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.cancel")) {
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
            .alert(String(localized: "error.title"), isPresented: $showError) {
                Button(String(localized: "common.ok"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                // Initialize cached formatted strings (performance optimization)
                formattedBaseAmount = formatAmount(baseAmount)
                formattedTransactionDate = formatDate(originalTransaction.transactionDate)
                loadInitialSplits()
            }
            .onDisappear {
                // Memory Management: Cancel any pending tasks
                loadTask?.cancel()
            }
        }
    }

    // MARK: - Memory Management Notes
    /*
     Memory Safety:
     1. SplitTransactionView is a struct (value type) - no retain cycles possible
     2. @EnvironmentObject (viewModel) is managed by SwiftUI - automatically deallocated
     3. Closures capture @State properties by value - safe from retain cycles
     4. onSave closure is owned by parent - parent responsible for lifecycle
     5. Task cancellation on disappear prevents lingering async work
     6. FlowLayout uses cache to avoid repeated calculations
     */

    private var mainContent: some View {
        LazyVStack(spacing: 20) {
            // Original Transaction Card
            originalTransactionCard

            // Split Allocation Visualization
            splitAllocationView

            if shouldShowRetainParentToggle {
                Toggle(isOn: $retainParent) {
                    Text(String(localized: "split.retainParent"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                if !retainParent {
                    Text(String(localized: "split.retainParentDescription"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }

            // Split Items List
            VStack(spacing: 12) {
                HStack {
                    Text(String(localized: "split.splits"))
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

                ForEach(Array($splitItems.enumerated()), id: \.element.id) { index, $item in
                    SplitItemRow(
                        splitItem: $item,
                                totalAmount: baseAmount,
                        index: index,
                        onDelete: {
                            withAnimation {
                                let id = item.id
                                splitItems.removeAll { $0.id == id }
                            }
                        },
                        onCategorySelect: {
                            if let idx = splitItems.firstIndex(where: { $0.id == item.id }) {
                                categoryPickerContext = CategoryPickerContext(
                                    index: idx,
                                    currentCategory: splitItems[idx].category
                                )
                            }
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
                        Text(String(localized: "split.addSplit"))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("AddSplitComponent")
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
                Text(String(localized: "split.originalTransaction"))
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
                            Text("#\(category.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(formattedTransactionDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formattedBaseAmount)
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
                Text(String(localized: "split.allocation"))
                    .font(.headline)
                Spacer()

                HStack(spacing: 4) {
                    Text(String(localized: "split.remaining"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(remainingAmount))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isRemainingBalanced ? .green : .orange)
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
                        ForEach(positiveSplits, id: \.item.id) { split in
                            let ratio = totalAmountDouble > 0
                                ? (split.item.amount as NSDecimalNumber).doubleValue / totalAmountDouble
                                : 0
                            let clampedRatio = max(0, min(ratio, 1))
                            let width = geometry.size.width * CGFloat(clampedRatio)

                            Rectangle()
                                .fill(Color(hex: split.category.colorHex))
                                .frame(width: width, height: 24)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(height: 24)

            // Legend
            if !positiveSplits.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(positiveSplits, id: \.item.id) { split in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: split.category.colorHex))
                                .frame(width: 8, height: 8)
                            Text(split.category.displayName)
                                .font(.caption2)
                            Text(split.item.formattedAmount)
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
                        Text(String(localized: "split.save"))
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
            .accessibilityIdentifier("SaveButton")
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
            retainParent = true
        } else {
            // Create initial split with remaining amount
            splitItems = []
            retainParent = true
        }
    }

    private func saveSplit() {
        guard isValid else {
            errorMessage = validationError ?? String(localized: "error.invalidData")
            showError = true
            return
        }

        isSaving = true

        // Call the save handler (synchronous - parent handles async operations)
        onSave(splitItems, retainParent)

        // Delay dismiss slightly for smooth animation
        // Note: Using Task with MainActor for proper structured concurrency
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Check if still saving (could be cancelled)
            guard isSaving else { return }

            isSaving = false
            dismiss()
        }
    }

    // MARK: - Formatters
    private func formatAmount(_ amount: Decimal) -> String {
        Formatters.currencyStringUAH(amount: amount)
    }

    private func formatDate(_ date: Date) -> String {
        Formatters.dateString(date)
    }

    private var shouldShowRetainParentToggle: Bool {
        originalTransaction.parentTransactionId == nil
    }
}

// MARK: - Category Picker Sheet
private struct SplitCategoryPickerSheet: View {
    let selectedCategory: Category?
    let onSelect: (Category) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransactionViewModel // Safe: SwiftUI manages lifecycle
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

                            Text(category.displayName)
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .accessibilityIdentifier("Category_\(category.name)")
                }
            }
            .navigationTitle(String(localized: "common.selectCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: String(localized: "search.categories"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.close")) {
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

    // MARK: - Memory Optimization: Cache Layout Calculations
    struct Cache {
        var result: FlowResult?
        var lastWidth: CGFloat?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width

        // Use cached result if width hasn't changed
        if let cachedResult = cache.result, cache.lastWidth == width {
            return cachedResult.size
        }

        // Calculate new layout and cache it
        let result = FlowResult(
            in: width,
            subviews: subviews,
            spacing: spacing
        )
        cache.result = result
        cache.lastWidth = width
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let width = bounds.width

        // Use cached result if width hasn't changed
        if let cachedResult = cache.result, cache.lastWidth == width {
            for (index, subview) in subviews.enumerated() {
                subview.place(
                    at: CGPoint(x: bounds.minX + cachedResult.positions[index].x,
                               y: bounds.minY + cachedResult.positions[index].y),
                    proposal: .unspecified
                )
            }
            return
        }

        // Calculate new layout and cache it
        let result = FlowResult(
            in: width,
            subviews: subviews,
            spacing: spacing
        )
        cache.result = result
        cache.lastWidth = width

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x,
                           y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
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
