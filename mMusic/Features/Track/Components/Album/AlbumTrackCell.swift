import SwiftUI

struct AlbumTrackCell: View {

    var track: Track

    private var featuredNames: [String] {
        track.credits
            .filter { $0.role != .main }
            .sorted { $0.position < $1.position }
            .map { $0.artist.name }
    }

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.tint)
                .opacity(track.isFavourite ? 1 : 0)
                .frame(width: 16)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text("\(track.position)")
                }
            VStack(alignment: .leading) {
                Text(track.name)
                    .bold()
                    .lineLimit(1)
                if !featuredNames.isEmpty {
                    Text(featuredNames.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
