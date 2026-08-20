import SwiftData
import SwiftUI

struct EditPlaylistView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showImagePicker = false
    
    @Bindable var playlist: Playlist
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if let artworkData = playlist.artwork, let uiImage = UIImage(data: artworkData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    Image(systemName: "music.note")
                                }
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        
                        Spacer()
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("Pick an image", systemImage: "photo")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.glassProminent)
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(imageData: $playlist.artwork)
                        }
                    }
                }
                
                Section("playlist name") {
                    TextField(playlist.name, text: $playlist.name)
                }
                Section("description") {
                    TextField(playlist.playlistDescription, text: $playlist.playlistDescription)
                }
                
                if !playlist.orderedTracks.isEmpty {
                    Section("tracks") {
                        ForEach(playlist.orderedTracks) { track in
                            TrackCell(
                                track: track,
                                leadingStyle: .artwork,
                                onRemoveFromPlaylist: { remove(track) }
                            )
                        }
                        .onDelete { offsets in
                            removeTracks(at: offsets)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// Убирает трек из плейлиста, не трогая ни файл, ни запись в библиотеке:
    /// удаляется только связка `TrackPlaylistItem`.
    private func remove(_ track: Track) {
        guard let index = playlist.items
            .sorted(by: { $0.position < $1.position })
            .firstIndex(where: { $0.track.persistentModelID == track.persistentModelID })
        else { return }

        removeTracks(at: IndexSet(integer: index))
    }

    private func removeTracks(at offsets: IndexSet) {
        var items = playlist.items.sorted { $0.position < $1.position }

        for index in offsets where items.indices.contains(index) {
            modelContext.delete(items[index])
        }

        // Позиции пересчитываются, иначе в нумерации остаются дыры.
        items.remove(atOffsets: offsets)
        for (index, item) in items.enumerated() {
            item.position = index
        }
    }
}
