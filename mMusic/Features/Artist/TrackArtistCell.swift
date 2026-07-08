import SwiftUI

struct TrackArtistCell: View {
    
    var draft: ArtistDraft?
    var artist: Artist?
    var showDelete: Bool
    var onTap: () -> Void = {}
    var onRemove: () -> Void = {}

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
            if let draft = draft {
                Text(draft.name)
            }
            if let artist = artist {
                Text(artist.name)
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
        .background(Color.gray.opacity(0.2), in: Capsule())
        .fixedSize()
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
    }
}
