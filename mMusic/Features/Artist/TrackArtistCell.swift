import SwiftUI

struct TrackArtistCell: View {
    
    var name: String
    var role: CreditRole = .main
    
    var showDelete: Bool
    var showRole: Bool
    var editable: Bool
    
    var capsuleColor: Color {
        editable ? .gray : .white
    }
    var onTap: () -> Void = {}
    var onRemove: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
            Text(name)
            if showRole {
                Image(systemName: role == .main ? "star.fill" : "star")
            }
            if showDelete {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(capsuleColor.opacity(0.2), in: Capsule())
        .fixedSize()
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
    }
}
