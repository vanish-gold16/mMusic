import SwiftUI

struct PinnedPlaylistCell: View {
    var playlist: Playlist
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .overlay {
                    if let data = playlist.artwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
            Text(playlist.name)
                .bold()
            
        }
        .foregroundStyle(.primary)
    }
}
