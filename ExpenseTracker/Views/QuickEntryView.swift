//
//  QuickEntryView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI

struct QuickEntryView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @FocusState private var isDescriptionFocused: Bool
    @State private var showDatePicker = false
    
    var body : some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Amount input section
                VStack(spacing: 12) {
                    // Transaction type toggle
                    Picker("Type", selection: $viewModel.transactionType) {
                        Text("Витрата").tag(TransactionType.expense)
                        Text("Дохід").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Amount display
                    HStack {
                        Text(viewModel.transactionType.symbol)
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(viewModel.transactionType == .expense ? .red : .green)
                        TextField("0", text: $viewModel.entryAmount)
                            .font(.system(size: 40, weight: .light))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        
                        Text("₴")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                
                }
                
                // Date Selector
                HStack {
                    Label("Дата", systemImage: "calendar")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(action: { showDatePicker.toggle() } ) {
                        Text(viewModel.selectedDate, style: .date)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                
                // Category quick select
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.categories, id: \.id) { category in
                            CategoryChip(
                                category: category,
                                isSelected: viewModel.selectedCategory?.id == category.id
                            ) {
                                viewModel.selectedCategory = viewModel.selectedCategory?.id == category.id ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Description input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Опис")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    TextField("Наприклад: Таксі до Києва", text: $viewModel.entryDescription)
                        .textFieldStyle(.roundedBorder)
                        .focused($isDescriptionFocused)
                        .onChange(of: viewModel.entryDescription) {_, newValue in
                            if viewModel.selectedCategory == nil {
                                viewModel.selectedCategory = viewModel.suggestCategory(for: newValue)
                            }
                        }
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Add button
                Button(action: viewModel.addTransaction) {
                    Label("Додати", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isValidEntry ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!viewModel.isValidEntry)
                .padding(.horizontal)
                
                // Recent transactions preview
                if !viewModel.transactions.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Останні операції")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(viewModel.transactions.prefix(5)) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .onTapGesture {
                                            // TODO: Edit transaction
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .navigationTitle("Expense Tracker")
            .sheet(isPresented: $showDatePicker)
            {
                DatePicker("Оберіть дату", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .presentationDetents([.medium])
            }
        }
    }
}

#Preview {
    QuickEntryView()
}
