//
//  MainTabView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 07.09.2025.
//


import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: Int
    @Binding var showPendingBadge: Bool
    @EnvironmentObject var pendingViewModel: PendingTransactionsViewModel
    
    var body: some View {
        TabView(selection: $selectedTab) {
            QuickEntryView()
                .tabItem {
                    Label("Додати", systemImage: "plus.circle.fill")
                }
                .tag(0)
            
            TransactionListView()
                .tabItem {
                    Label("Транзакції", systemImage: "list.bullet")
                }
                .tag(1)
            
            PendingTransactionsView()
                .tabItem {
                    Label("Очікує", systemImage: "clock.fill")
                }
                .badge(pendingViewModel.pendingTransactions.count)
                .tag(2)
            
            AccountsView()
                .tabItem {
                    Label("Рахунки", systemImage: "creditcard.fill")
                }
                .tag(3)
            
            AnalyticsView()
                .tabItem {
                    Label("Аналітика", systemImage: "chart.pie.fill")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}