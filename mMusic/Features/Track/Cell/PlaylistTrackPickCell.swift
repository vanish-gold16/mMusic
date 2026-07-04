import SwiftUI

struct PlaylistTrackPickCell: View {
    
    var track: Track
    var playlist: Playlist

    private var isPicked: Bool {
        playlist.tracks.contains(track)
    }

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let data = track.artwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
            VStack {
                Text(track.name)
                    .bold()
                Text(track.artist)
                    .foregroundStyle(.secondary)
            }
            Button {
                
            } label: {
                if isPicked {
                    Image(systemName: "checkmark.circle.dotted")
                } else {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    func swapIsPicked() {
        if isPicked {
            playlist.tracks.remove(at: track.id)
        }
    }
}
