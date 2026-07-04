import SwiftUI

struct PlaylistTrackCell: View {
    
    var track: Track
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 40)
                .overlay {
                    if let data = track.artwork, let uiImage = UIImage(data: data) {
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
                Text(track.artist)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
