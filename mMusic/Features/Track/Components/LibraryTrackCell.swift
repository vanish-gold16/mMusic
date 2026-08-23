import SwiftData
import SwiftUI

struct LibraryTrackCell: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts
    
    @State private var showImagePicker = false
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    
    let track: Track
    
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
            Text(track.name)
                .lineLimit(1)
            Text(track.artistNames.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .onTapGesture {
            audioPlayer.play([track])
        }
        .contextMenu() {
            VStack {
                ControlGroup {
                    Button {
                        track.isFavourite.toggle()
                    } label: {
                        Label("Favourite", systemImage: track.isFavourite ? "star.fill" : "star")
                    }

                    ShareLink(item: AudioFileStore.url(for: track.filename)) {
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
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .sheet(isPresented: $showEdit) {
            EditTrackView(track: track)
        }
        .confirmationDialog(
            "Remove \"\(track.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                let name = track.name
                // Номера в альбоме пересчитываются до удаления: после него ссылка
                // на трек уже невалидна, а дыру в нумерации закрыть нужно.
                track.album?.renumberTracks(excluding: track)

                audioPlayer.forget(track)
                AudioFileStore.remove(filename: track.filename)
                modelContext.delete(track)

                toasts.removed("Deleted \(name)")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This track will be permanently deleted.")
        }
    }
}
