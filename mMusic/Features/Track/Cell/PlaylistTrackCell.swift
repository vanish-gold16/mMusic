import SwiftUI

struct PlaylistTrackCell: View {

    var track: Track

    var body: some View {
        HStack {
            Group {
                if track.isFavourite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "")
                }
            }
            .frame(width: 10)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
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
                    .lineLimit(1)
                Text(track.artist)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
