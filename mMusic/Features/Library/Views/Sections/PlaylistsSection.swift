import SwiftData
import SwiftUI

/// Плейлисты одним списком: закреплённые сверху, остальные следом.
/// Отдельной полки «Pinned» больше нет — она дублировала тот же список.
///
/// В конце — пунктирный слот нового плейлиста, как «Add music» в самом плейлисте:
/// создать его можно и из «+» наверху, но там, где кончается список, — нагляднее.
struct PlaylistsSection: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    @State private var editedPlaylist: Playlist?
    @State private var playlistToDelete: Playlist?
    @State private var showCreatePlaylist = false

    /// Тот же порядок, что и на других экранах, где плейлисты листают, — см. `byLastPlayed`.
    private var ordered: [Playlist] {
        playlists.byLastPlayed
    }

    var body: some View {
        Group {
            if playlists.isEmpty {
                DashedSlot(title: "Create the first playlist", isLarge: true, cornerRadius: 28) {
                    showCreatePlaylist = true
                }
                .padding(.horizontal)
            } else {
                list
            }
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
        }
    }

    private var list: some View {
        LazyVStack(spacing: 10) {
            ForEach(ordered) { playlist in
                NavigationLink {
                    PlaylistView(playlist: playlist)
                } label: {
                    PlaylistCell(playlist: playlist)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(for: playlist) }
            }

            DashedSlot(title: "New playlist", cornerRadius: 28) {
                showCreatePlaylist = true
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .sheet(item: $editedPlaylist) { playlist in
            EditPlaylistView(playlist: playlist)
        }
        .confirmationDialog(
            "Delete \"\(playlistToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { playlistToDelete != nil },
                set: { if !$0 { playlistToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: playlistToDelete
        ) { playlist in
            Button("Delete", role: .destructive) {
                let name = playlist.name
                modelContext.delete(playlist)
                toasts.removed("Deleted \(name)")
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This playlist will be permanently deleted.")
        }
    }

    @ViewBuilder
    private func menu(for playlist: Playlist) -> some View {
        ControlGroup {
            Button {
                playlist.isPinned.toggle()
            } label: {
                Label(playlist.isPinned ? "Unpin" : "Pin", systemImage: playlist.isPinned ? "pin.fill" : "pin")
            }
            ShareLink(items: playlist.orderedTracks.map { AudioFileStore.url(for: $0.filename) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        Button {
            playlist.markPlayed()
            audioPlayer.play(playlist.orderedTracks)
        } label: {
            Label("Play", systemImage: "play")
        }
        Button {
            playlist.markPlayed()
            audioPlayer.playShuffled(playlist.orderedTracks)
        } label: {
            Label("Shuffle", systemImage: "shuffle")
        }

        Divider()

        Button {
            editedPlaylist = playlist
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Divider()

        Button {
            audioPlayer.enqueueNext(playlist.orderedTracks)
            toasts.enqueuedNext(playlist.orderedTracks.count)
        } label: {
            Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        Button {
            audioPlayer.enqueueLast(playlist.orderedTracks)
            toasts.enqueuedLast(playlist.orderedTracks.count)
        } label: {
            Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
        }

        Divider()

        Button(role: .destructive) {
            playlistToDelete = playlist
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
