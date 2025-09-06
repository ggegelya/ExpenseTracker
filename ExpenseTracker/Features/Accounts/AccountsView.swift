//
//  AccountsView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var viewModel: AccountsViewModel
    @State private var showAddAccount = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.accounts) { account in
                    AccountRow(account: account)
                        .swipeActions(edge: .trailing) {
                            if !account.isDefault {
                                Button {
                                    Task {
                                        await viewModel.setAsDefault(account)
                                    }
                                } label: {
                                    Label("За замовчуванням", systemImage: "star")
                                }
                                .tint(.orange)
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteAccount(account)
                                }
                            } label: {
                                Label("Видалити", systemImage: "trash")
                            }
                        }
                }
                
                // Total balance
                if !viewModel.accounts.isEmpty {
                    Section {
                        HStack {
                            Text("Загальний баланс")
                                .font(.headline)
                            Spacer()
                            Text(formatAmount(totalBalance))
                                .font(.headline)
                                .foregroundColor(totalBalance >= 0 ? .green : .red)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Рахунки")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddAccount.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView()
            }
        }
    }
    
    private var totalBalance: Decimal {
        viewModel.accounts.reduce(0) { $0 + $1.balance }
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
    }
}





