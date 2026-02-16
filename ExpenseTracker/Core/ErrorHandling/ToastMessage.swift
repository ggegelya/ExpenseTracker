//
//  ToastMessage.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//


import Foundation
import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id && lhs.message == rhs.message && lhs.type == rhs.type
    }
}
