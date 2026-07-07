import SwiftUI

struct PlaylistTrackCell: View {

    @State private var showTrackEllipsis = false
    
    var track: Track

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.orange)
                .opacity(track.isFavourite ? 1 : 0)
                .frame(width: 16)
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
            Spacer()
            Button {
                showTrackEllipsis = true
            } label: {
                Image(systemName: "ellipsis")
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showTrackEllipsis) {
            Menu {
                
            } label: {
                
            }
        }
    }
}
