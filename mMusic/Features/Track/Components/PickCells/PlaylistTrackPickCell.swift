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
            .tint(.orange)
        }
        .padding(.horizontal)
    }
    
    func swapIsPicked() {
        if isPicked {
            playlist.tracks.removeAll { $0 == track }
        } else {
            playlist.tracks.append(track)
        }
    }
}
