//
//  MetadataEditorSheet.swift
//  ExpenseTracker
//

import SwiftUI

struct MetadataEditorSheet: View {
    @Binding var selectedDate: Date
    @Binding var selectedAccount: Account?
    let accounts: [Account]
    let showAccountSelector: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "common.date"))
                            .font(.headline)

                        DatePicker(
                            String(localized: "metadata.selectDate"),
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }

                    // Account Selector (only if more than 1 account)
                    if showAccountSelector {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "common.account"))
                                .font(.headline)

                            ForEach(accounts) { account in
                                Button {
                                    selectedAccount = account
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(account.displayName)
                                                .font(.body)
                                                .foregroundColor(.primary)
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedAccount?.id == account.id
                                            ? Color.blue.opacity(0.1)
                                            : Color(.systemGray6)
                                    )
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("AccountsList")
            .navigationTitle(String(localized: "transactionDetail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

}
