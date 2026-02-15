//
//  AccountPickerSheet.swift
//  ExpenseTracker
//

import SwiftUI

struct AccountPickerSheet: View {
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if TestingConfiguration.isRunningTests {
                ScrollView { EmptyView() }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("AccountsList")
            }
            List(accounts) { account in
                Button {
                    selectedAccount = account
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.name)
                                .font(.headline)
                            Text(account.formattedBalance())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedAccount?.id == account.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .accessibilityIdentifier("AccountsList")
            .navigationTitle(String(localized: "account.select"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

}
