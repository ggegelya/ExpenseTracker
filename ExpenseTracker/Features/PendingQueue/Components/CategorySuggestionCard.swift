//
//  CategorySuggestionCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct CategorySuggestionCard: View {
    let suggestedCategory: Category?
    let confidence: Float
    let onCategorySelect: (Category) -> Void

    @State private var showCategoryPicker = false
    @State private var searchText = ""
    @EnvironmentObject var transactionViewModel: TransactionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "common.category"))
                    .font(.headline)
                Spacer()
                if suggestedCategory != nil {
                    confidenceBadge
                }
            }

            if let category = suggestedCategory {
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.colorHex))
                            .frame(width: 32, height: 32)
                            .background(Color(hex: category.colorHex).opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(category.displayName)
                            .font(.body)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("CategoryPicker")
            } else {
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.orange)
                            .frame(width: 32, height: 32)

                        Text(String(localized: "common.selectCategory"))
                            .font(.body)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("CategoryPicker")
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                selectedCategory: suggestedCategory,
                onSelect: { category in
                    onCategorySelect(category)
                    showCategoryPicker = false
                }
            )
        }
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon)
                .font(.caption2)
            Text(confidenceText)
                .font(.caption)
        }
        .foregroundColor(confidenceColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var confidenceIcon: String {
        if confidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if confidence >= 0.5 {
            return "exclamationmark.circle.fill"
        } else {
            return "questionmark.circle.fill"
        }
    }

    private var confidenceText: String {
        if confidence >= 0.8 {
            return String(localized: "confidence.high")
        } else if confidence >= 0.5 {
            return String(localized: "confidence.medium")
        } else {
            return String(localized: "confidence.low")
        }
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Category Picker View
struct CategoryPickerView: View {
    let selectedCategory: Category?
    let onSelect: (Category) -> Void

    @State private var searchText = ""
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var loadError: Error?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var transactionViewModel: TransactionViewModel

    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return categories
        }
        return categories.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(String(localized: "loading.categories"))
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text(String(localized: "error.loadCategories"))
                            .font(.headline)

                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(String(localized: "common.retry")) {
                            Task { @MainActor in
                                await loadCategories()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if categories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text(String(localized: "common.noCategories"))
                            .font(.headline)

                        Text(String(localized: "category.createInSettings"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
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
                        }
                    }
                    .searchable(text: $searchText, prompt: String(localized: "search.categories"))
                }
            }
            .navigationTitle(String(localized: "common.selectCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .task { @MainActor in
                await loadCategories()
            }
        }
    }

    private func loadCategories() async {
        isLoading = true
        loadError = nil
        let loaded = transactionViewModel.categories
        categories = loaded.isEmpty ? Category.defaults : loaded
        isLoading = false
    }
}
