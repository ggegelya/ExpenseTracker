//
//  ToastMessage.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//


import Foundation
import SwiftUI

struct ToastMessage: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
}


