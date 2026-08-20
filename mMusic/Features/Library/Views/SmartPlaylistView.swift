import SwiftData
import SwiftUI

/// Содержимое автоподборки. Пересчитывается на лету из `@Query`, поэтому
/// хранить её как настоящий плейлист незачем — она всегда актуальна.
struct SmartPlaylistView: View {

    let playlist: SmartPlaylist

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext

    @Query private var allTracks: [Track]

    @State private var didSave = false

    private var tracks: [Track] {
        playlist.tracks(from: allTracks)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text(playlist.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if tracks.isEmpty {
                    LibraryEmptyState(text: "Nothing here right now")
                } else {
                    buttons

                    ForEach(tracks) { track in
                        TrackCell(track: track, queue: tracks, leadingStyle: .artwork, showPlayCount: true)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(playlist.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveAsPlaylist()
                } label: {
                    Image(systemName: didSave ? "checkmark" : "text.badge.plus")
                }
                .disabled(tracks.isEmpty || didSave)
            }
        }
    }

    private var buttons: some View {
        HStack {
            Button {
                audioPlayer.play(tracks)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.glassProminent)

            Button {
                audioPlayer.playShuffled(tracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal)
    }

    /// Слепок подборки на сегодня: сама она завтра изменится, а сохранённый плейлист — нет.
    private func saveAsPlaylist() {
        let saved = Playlist(name: playlist.title, items: [])
        modelContext.insert(saved)

        for (position, track) in tracks.enumerated() {
            modelContext.insert(TrackPlaylistItem(track: track, playlist: saved, position: position))
        }

        didSave = true
    }
}
