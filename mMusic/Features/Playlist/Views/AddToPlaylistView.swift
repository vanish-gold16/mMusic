import SwiftData
import SwiftUI

/// Куда положить треки: в существующий плейлист или в новый, созданный тут же.
struct AddToPlaylistView: View {

    let tracks: [Track]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts

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
                            .submitLabel(.done)
                            .onSubmit { if !trimmedName.isEmpty { createAndAdd() } }

                        Button("Create") { createAndAdd() }
                            .buttonStyle(.glassProminent)
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
                        ForEach(playlists.byLastAdded) { playlist in
                            Button {
                                add(to: playlist)
                            } label: {
                                row(for: playlist)
                            }
                            .buttonStyle(.plain)
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
        // Лист открывается наполовину: список плейлистов короткий, а закрывать
        // его протяжкой удобнее, чем целиться в «cancel».
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(for playlist: Playlist) -> some View {
        let alreadyThere = countAlreadyThere(in: playlist)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 40, height: 40)
                .overlay {
                    if let data = playlist.artwork ?? playlist.orderedTracks.first?.displayArtwork,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Про дубли честнее сказать до нажатия, а не после: иначе выбор
                // выглядит как «нажал — и ничего не произошло».
                Text(subtitle(count: playlist.items.count, alreadyThere: alreadyThere))
                    .font(.caption)
                    .foregroundStyle(alreadyThere > 0 ? Color.orange : Color.secondary)
            }

            Spacer()

            if alreadyThere == tracks.count {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
    }

    private func subtitle(count: Int, alreadyThere: Int) -> String {
        if alreadyThere == 0 {
            return count == 1 ? "1 track" : "\(count) tracks"
        }

        if alreadyThere == tracks.count {
            return tracks.count == 1 ? "already here" : "all \(tracks.count) already here"
        }

        return "\(alreadyThere) of \(tracks.count) already here"
    }

    /// Сколько из выбранных треков уже лежит в плейлисте.
    private func countAlreadyThere(in playlist: Playlist) -> Int {
        let existing = Set(playlist.items.map(\.track.persistentModelID))
        return tracks.filter { existing.contains($0.persistentModelID) }.count
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

        // Раньше про пропуски сообщал алерт с кнопкой «ОК» — он останавливал
        // на ровном месте. Теперь то же самое говорит плашка, которая гаснет сама.
        toasts.addedToPlaylist(added: added, skipped: tracks.count - added, playlist: playlist.name)
        dismiss()
    }
}
