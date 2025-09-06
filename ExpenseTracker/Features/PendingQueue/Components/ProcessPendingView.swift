//
//  ProcessPendingView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import SwiftUI

struct ProcessPendingView: View {
    let pending: PendingTransaction
    
    var body: some View {
        Text("Process: \(pending.descriptionText)")
    }
}