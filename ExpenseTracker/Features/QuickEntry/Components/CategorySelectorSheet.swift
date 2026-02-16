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
                            ForEach(sortedCategories) { category in
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

    private var sortedCategories: [Category] {
        let filtered = searchText.isEmpty
            ? categories
            : categories.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }

        // When not searching, sort favorites first
        guard searchText.isEmpty else { return filtered }

        let favoriteIds = Self.loadFavoriteCategoryIds()
        guard !favoriteIds.isEmpty, favoriteIds.count < categories.count else {
            return filtered
        }

        return filtered.sorted { a, b in
            let aFav = favoriteIds.contains(a.id)
            let bFav = favoriteIds.contains(b.id)
            if aFav != bFav { return aFav }
            return false // preserve original order within each group
        }
    }

    static func loadFavoriteCategoryIds() -> Set<UUID> {
        guard let strings = UserDefaults.standard.stringArray(forKey: UserDefaultsKeys.favoriteCategoryIds) else {
            return []
        }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
}
