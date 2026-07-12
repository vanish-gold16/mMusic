import SwiftData
import SwiftUI

struct AlbumCell: View {
    
    @Environment(\.modelContext) private var modelContext

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
                Text(album.name)
                Text(album.artistNames.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            VStack {
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
