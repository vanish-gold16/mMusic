import SwiftUI

struct TrackCell: View {
    
    @Environment(AudioPlayer.self) private var audioPlayer

    var track: Track

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.orange)
                .opacity(track.isFavourite ? 1 : 0)
                .frame(width: 16)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
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
                    .lineLimit(1)
                Text(track.artistNames.joined(separator: ", "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                ControlGroup {
                    Button {

                    } label: {
                        Label("Favourite", systemImage: track.isFavourite ? "star.fill" : "star")
                    }
                    Button {

                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

                Divider()
                
                Button {
                    
                } label: {
                    Label("Add to a Playlist", systemImage: "text.badge.plus")
                }
                
                Divider()

                Button {

                } label: {
                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button {

                } label: {
                    Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                }

                Divider()
                
                Button {
                    
                } label: {
                    Label("Go to Album", systemImage: "music.note.square.stack")
                }
                
                Divider()

                Button(role: .destructive) {

                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .onTapGesture {
            audioPlayer.play(track)
        }
    }
}
