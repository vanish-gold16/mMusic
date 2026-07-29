import SwiftData
import SwiftUI

struct AlbumCell: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer

    @State private var showDeleteConfirmation = false

    let album: Album
    
    var body: some View {
        NavigationLink {
            AlbumView(album: album)
        } label: {
            VStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let data = album.artwork, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "music.note")
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if album.isFavourite {
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundStyle(.yellow)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(8)
                        }
                    }
                Text(album.name)
                Text(album.artistNames.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            VStack {
                Button {
                    album.isFavourite.toggle()
                } label: {
                    Label("Favorite", systemImage: album.isFavourite ? "star.fill" : "star")
                }
                
                Divider()
                
                Button {
                    audioPlayer.play(album.tracks.sorted { $0.position < $1.position })
                } label: {
                    Label("Play", systemImage: "play")
                }
                Button {
                    audioPlayer.play(album.tracks.shuffled())
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                
                Divider()
                
                Button {
                    
                } label: {
                    Label("Add to playlist", systemImage: "text.badge.plus")
                }
                
                Divider()
                
                Button {
                    audioPlayer.queue.insert(contentsOf: album.tracks.sorted { $0.position < $1.position }, at: 0)
                } label: {
                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                
                Button {
                    audioPlayer.queue.append(contentsOf: album.tracks.sorted { $0.position < $1.position })
                } label: {
                    Label("Play After", systemImage: "text.line.last.and.arrowtriangle.forward")
                }
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete album", systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Delete \"\(album.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteAlbum()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This album and all its tracks will be permanently deleted.")
        }
    }
    
    private func deleteAlbum() {
        for track in album.tracks {
            let url = URL.documentsDirectory.appending(path: track.filename)
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(album)
    }
    
}
