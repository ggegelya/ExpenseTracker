//
//  ToastType.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//

import Foundation
import SwiftUICore

enum ToastType {
    case success, warning, error, info
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .yellow
        case .error: return .red
        case .info: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
}


