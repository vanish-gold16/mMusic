import SwiftData
import SwiftUI

/// Куда положить треки: в существующий плейлист или в новый, созданный тут же.
struct AddToPlaylistView: View {

    let tracks: [Track]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    @State private var newPlaylistName = ""
    /// Сообщение о том, сколько треков легло, а сколько уже было.
    @State private var result: String?

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
            .alert(
                "Added",
                isPresented: Binding(
                    get: { result != nil },
                    set: { if !$0 { result = nil } }
                ),
                presenting: result
            ) { _ in
                Button("OK") { dismiss() }
            } message: { message in
                Text(message)
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

        var added = 0

        for track in tracks where !existing.contains(track.persistentModelID) {
            modelContext.insert(TrackPlaylistItem(track: track, playlist: playlist, position: position))
            position += 1
            added += 1
        }

        let skipped = tracks.count - added

        // Про пропуски нужно сказать: молчаливое «ничего не произошло» выглядит
        // как сбой, особенно когда добавляешь альбом целиком.
        guard skipped > 0 else {
            dismiss()
            return
        }

        result = added == 0
            ? "All \(skipped) tracks are already in \"\(playlist.name)\"."
            : "\(added) added, \(skipped) already there."
    }
}
