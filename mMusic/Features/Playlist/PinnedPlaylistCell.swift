import SwiftUI

struct PinnedPlaylistCell: View {
    var playlist: Playlist
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let data = playlist.artwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(playlist.name)
                .bold()
                .lineLimit(1)
                .foregroundStyle(Color.primary)
        }
        .foregroundStyle(.primary)
    }
}
