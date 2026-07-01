import SwiftData
import SwiftUI

struct TrackCell: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImagePicker = false
    @State private var showEdit = false
    
    let track: Track
    
    var body: some View {
        @Bindable var track = track
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let data = track.artwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
            Text(track.name)
                .lineLimit(1)
            Text(track.artist)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            audioPlayer.play(track)
        }
        .contextMenu() {
            VStack {
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
                    showEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    let url = URL.documentsDirectory.appending(path: track.filename)
                    try? FileManager.default.removeItem(at: url)
                    modelContext.delete(track)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                .tint(.red)
            }
        }
        .sheet(isPresented: $showEdit) {
            
        }
    }
}
