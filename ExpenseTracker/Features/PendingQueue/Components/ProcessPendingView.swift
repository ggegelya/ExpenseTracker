import Foundation
import SwiftUI

struct ProcessPendingView: View {
    let pending: PendingTransaction
    
    var body: some View {
        Text("Process: \(pending.descriptionText)")
    }
}