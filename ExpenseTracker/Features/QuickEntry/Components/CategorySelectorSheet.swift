//
//  CategorySelectorSheet.swift
//  ExpenseTracker
//

import SwiftUI

struct CategorySelectorSheet: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    let recentCategories: [Category]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(String(localized: "search.categories"), text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Recent Categories Section
                    if !TestingConfiguration.isRunningTests && !recentCategories.isEmpty && searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "category.recentlyUsed"))
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(recentCategories) { category in
                                    CategoryGridItem(
                                        category: category,
                                        isSelected: selectedCategory?.id == category.id
                                    ) {
                                        selectedCategory = category
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // All Categories Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(searchText.isEmpty ? String(localized: "category.all") : String(localized: "search.results"))
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(filteredCategories) { category in
                                CategoryGridItem(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id
                                ) {
                                    selectedCategory = category
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(String(localized: "filter.categories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { category in
                category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
