import SwiftUI

struct AlbumTrackPickCell: View {
    
    var track: Track
    @Binding var addedTracks: [TrackDraft]
    
    private var isPicked: Bool {
        addedTracks.contains { matches($0) }
    }

    private func matches(_ draft: TrackDraft) -> Bool {
        draft.name == track.name && draft.artists.map(\.name) == track.artistNames
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
            VStack {
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
            addedTracks.removeAll { matches($0) }
        } else {
            var draftArtists: [ArtistDraft] = []
                for name in track.artistNames {
                    draftArtists.append(ArtistDraft(name: name))
            }
            
            let draft = TrackDraft(
                name: track.name,
                genre: track.genre,
                artists: draftArtists,
                stagedURL: URL.documentsDirectory.appending(path: track.filename)
            )
        }
    }
    
}
