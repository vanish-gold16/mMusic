import SwiftUI

struct AlbumTrackDraftCell: View {
    var draft: TrackDraft
    var position: Int
    
    private var featuredNames: [String] {
        var names: [String] = []
        for artist in draft.artists {
            if artist.role != .main {
                names.append(artist.name)
            }
        }
        return names
    }
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text("\(position)")
                }
            VStack(alignment: .leading) {
                Text(draft.name)
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
