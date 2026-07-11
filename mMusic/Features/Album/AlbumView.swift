import SwiftUI

struct AlbumView: View {
    var album: Album
    
    var body: some View {
        ScrollView {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)
                    .overlay {
                        if let data = album.artwork, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "music.note")
                        }
                    }
                VStack {
                    Text(album.name)
                        .font(.title)
                        .bold()
                    Text(album.artistNames.joined(separator: ", "))
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(album.genres.map(\.rawValue).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            ForEach(album.tracks) { track in
                TrackCell(track: track)
            }
        }
    }
}
