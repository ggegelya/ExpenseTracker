//
//  PendingTransactionView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct PendingTransactionsView: View {
    @EnvironmentObject var viewModel: PendingTransactionsViewModel
    @State private var selectedPending: PendingTransaction?
    @State private var showBatchProcessing = false
    @State private var dismissedIds: Set<UUID> = []
    @State private var showUndoToast = false
    @State private var lastDismissedPending: PendingTransaction?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(viewModel.pendingTransactions) { pending in
                        PendingTransactionRow(
                            pending: pending,
                            isProcessing: viewModel.processingIds.contains(pending.id)
                        ) {
                            selectedPending = pending
                        } onAccept: {
                            Task { @MainActor in
                                await handleQuickAccept(pending)
                            }
                        } onDismiss: {
                            handleQuickDismiss(pending)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.pendingTransactions.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.circle.fill",
                            title: String(localized: "pending.empty.title"),
                            subtitle: String(localized: "pending.empty.subtitle")
                        )
                    }
                }
                .accessibilityIdentifier("PendingTransactionList")
                .navigationTitle(String(localized: "pending.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !viewModel.pendingTransactions.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu {
                                Button {
                                    Task { @MainActor in
                                        await viewModel.processAllPending()
                                    }
                                } label: {
                                    Label(String(localized: "pending.acceptAll"), systemImage: "checkmark.circle")
                                }

                                Button {
                                    showBatchProcessing = true
                                } label: {
                                    Label(String(localized: "pending.reviewAll"), systemImage: "list.bullet")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .sheet(item: $selectedPending) { pending in
                    ProcessPendingView(pending: pending)
                        .environmentObject(viewModel)
                }
                .sheet(isPresented: $showBatchProcessing) {
                    BatchProcessingView(
                        pendingTransactions: viewModel.pendingTransactions
                    )
                    .environmentObject(viewModel)
                }
                .refreshable {
                    await viewModel.loadPendingTransactions()
                }

                // Undo Toast
                if showUndoToast {
                    undoToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Learning Toast
                if viewModel.showLearningToast, let notification = viewModel.learningNotification {
                    learningToast(notification: notification)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Learning Toast
    private func learningToast(notification: PendingTransactionsViewModel.LearningNotification) -> some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "pending.learned"))
                    .fontWeight(.semibold)
                Text("'\(notification.merchantName)' → \(notification.categoryName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: 1)
        )
        .padding()
        .shadow(radius: 10)
    }

    // MARK: - Undo Toast
    private var undoToast: some View {
        HStack {
            Image(systemName: "trash")
            Text(String(localized: "pending.dismissed"))
                .fontWeight(.medium)

            Spacer()

            Button(String(localized: "common.undo")) {
                undoDismiss()
            }
            .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .shadow(radius: 10)
    }

    // MARK: - Actions
    private func handleQuickAccept(_ pending: PendingTransaction) async {
        // Accept with suggested category
        await viewModel.processPendingTransaction(pending)
    }

    private func handleQuickDismiss(_ pending: PendingTransaction) {
        // Store for undo
        lastDismissedPending = pending
        dismissedIds.insert(pending.id)

        // Show undo toast
        withAnimation {
            showUndoToast = true
        }

        // Auto-hide toast and perform dismiss
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if dismissedIds.contains(pending.id) {
                await performDismiss(pending)
            }
        }
    }

    private func performDismiss(_ pending: PendingTransaction) async {
        await viewModel.dismissPendingTransaction(pending)
        dismissedIds.remove(pending.id)
        withAnimation {
            showUndoToast = false
        }
    }

    private func undoDismiss() {
        guard let pending = lastDismissedPending else { return }
        dismissedIds.remove(pending.id)
        withAnimation {
            showUndoToast = false
        }
        lastDismissedPending = nil
    }
}

