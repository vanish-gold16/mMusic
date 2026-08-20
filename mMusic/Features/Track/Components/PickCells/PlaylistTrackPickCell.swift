import SwiftData
import SwiftUI

struct PlaylistTrackPickCell: View {
    
    @Environment(\.modelContext) var modelContext
    
    var track: Track
    var playlist: Playlist

    private var isPicked: Bool {
        playlist.items.contains { $0.track == track }
    }

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
            VStack(alignment: .leading) {
                Text(track.name)
                    .bold()
                Text(track.artistNames.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                swapIsPicked()
            } label: {
                if isPicked {
                    Image(systemName: "checkmark.circle.dotted")
                } else {
                    Image(systemName: "plus")
                }
            }
        }
        .padding(.horizontal)
    }
    
    func swapIsPicked() {
        if isPicked {
            if let item = playlist.items.first(where: { $0.track == track }) {
                playlist.items.removeAll { $0.track == track }
                modelContext.delete(item)
            }
        } else {
            let position = (playlist.items.map(\.position).max() ?? -1) + 1
            let item = TrackPlaylistItem(track: track, playlist: playlist, position: position)
            playlist.items.append(item)
        }
    }
}
