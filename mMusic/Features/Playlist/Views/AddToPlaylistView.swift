import SwiftData
import SwiftUI

/// Куда положить треки: в существующий плейлист или в новый, созданный тут же.
struct AddToPlaylistView: View {

    let tracks: [Track]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    @State private var newPlaylistName = ""

    private var trimmedName: String {
        newPlaylistName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("new playlist") {
                    HStack {
                        TextField("Name", text: $newPlaylistName)
                        Button("Create") { createAndAdd() }
                            .disabled(trimmedName.isEmpty)
                    }
                }

                if playlists.isEmpty {
                    Section {
                        Text("No playlists yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("playlists") {
                        ForEach(playlists) { playlist in
                            Button {
                                add(to: playlist)
                            } label: {
                                HStack {
                                    Text(playlist.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(playlist.items.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(tracks.count == 1 ? "Add to playlist" : "Add \(tracks.count) tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
    }

    private func createAndAdd() {
        let playlist = Playlist(name: trimmedName, items: [])
        modelContext.insert(playlist)
        add(to: playlist)
    }

    /// Уже лежащие в плейлисте треки пропускаются — иначе повторное нажатие
    /// набивает плейлист дублями.
    private func add(to playlist: Playlist) {
        let existing = Set(playlist.items.map(\.track.persistentModelID))
        var position = playlist.items.count

        for track in tracks where !existing.contains(track.persistentModelID) {
            modelContext.insert(TrackPlaylistItem(track: track, playlist: playlist, position: position))
            position += 1
        }

        dismiss()
    }
}
