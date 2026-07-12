import SwiftData
import SwiftUI

struct CreateAlbumView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    
    var body: some View {
        NavigationStack {
            Form {
                
            }
            .navigationTitle("New album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        dismiss()
                    }
                }
            }
        }
    }
}
