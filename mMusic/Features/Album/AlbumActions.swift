import SwiftData
import SwiftUI

/// Что открывает пункт меню альбома. Как у трека (`TrackAction`), листы
/// и вопрос живут у владельца меню, а не в пунктах.
enum AlbumAction: Hashable, Identifiable {
    case edit
    case addToPlaylist
    case delete
    case artist(Artist)

    var id: Self { self }
}

/// Пункты меню альбома — одни и те же в сетке, в стопке на главной,
/// в ящике и на странице самого альбома. Раньше со страницы альбома
/// его нельзя было удалить, а из сетки — поправить.
struct AlbumMenuItems: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    let album: Album
    @Binding var action: AlbumAction?
    /// На странице самого альбома звезда, запуск и авторы и так на виду —
    /// в меню они не повторяются.
    var isOnItsPage = false

    var body: some View {
        // У сингла сюда входит и его песня, живущая в альбоме: см. `Album.tracklist`.
        let tracks = album.tracklist

        if !isOnItsPage {
            Button {
                album.isFavourite.toggle()
            } label: {
                Label("Favourite", systemImage: album.isFavourite ? "star.fill" : "star")
            }

            if !tracks.isEmpty {
                Divider()

                Button {
                    audioPlayer.play(tracks)
                } label: {
                    Label("Play", systemImage: "play")
                }
                Button {
                    audioPlayer.playShuffled(tracks)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
            }

            Divider()
        }

        if !tracks.isEmpty {
            // Треки уходят в порядке альбома: tracklist уже упорядочен
            // по position, а плейлист раздаёт позиции подряд.
            Button {
                action = .addToPlaylist
            } label: {
                Label("Add to a Playlist", systemImage: "text.badge.plus")
            }

            Button {
                audioPlayer.enqueueNext(tracks)
                toasts.enqueuedNext(tracks.count)
            } label: {
                Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                audioPlayer.enqueueLast(tracks)
                toasts.enqueuedLast(tracks.count)
            } label: {
                Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
            }

            Divider()
        }

        Button {
            action = .edit
        } label: {
            Label("Edit album", systemImage: "pencil")
        }

        if !isOnItsPage {
            GoToArtistItems(artists: album.artists) { artist in
                action = .artist(artist)
            }
        }

        if !tracks.isEmpty {
            ShareLink(items: tracks.map { AudioFileStore.url(for: $0.filename) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        Button(role: .destructive) {
            action = .delete
        } label: {
            Label("Delete album", systemImage: "trash")
        }
    }
}

extension View {

    /// Листы, вопрос об удалении и переход к артисту для `AlbumMenuItems`.
    ///
    /// `onLeave` — для страницы самого альбома: удалённый альбом нельзя
    /// оставлять на экране, поэтому сначала уходим с него.
    func albumActions(
        _ album: Album,
        action: Binding<AlbumAction?>,
        onLeave: (() -> Void)? = nil
    ) -> some View {
        modifier(AlbumActions(album: album, action: action, onLeave: onLeave))
    }
}

private struct AlbumActions: ViewModifier {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts

    let album: Album
    @Binding var action: AlbumAction?
    let onLeave: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isShowing(.edit)) {
                EditAlbumView(album: album)
            }
            .sheet(isPresented: isShowing(.addToPlaylist)) {
                AddToPlaylistView(tracks: album.tracklist)
            }
            .navigationDestination(item: artist) { artist in
                ArtistView(artist: artist)
            }
            .confirmationDialog(
                "Delete \"\(album.name)\"?",
                isPresented: isShowing(.delete),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteAfterLeaving(onLeave, delete: deleteAlbum)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This album and all its tracks will be permanently deleted.")
            }
    }

    private func isShowing(_ shown: AlbumAction) -> Binding<Bool> {
        Binding(
            get: { action == shown },
            set: { isShown in
                if !isShown, action == shown { action = nil }
            }
        )
    }

    private var artist: Binding<Artist?> {
        Binding(
            get: {
                guard case .artist(let artist) = action else { return nil }
                return artist
            },
            set: { artist in
                if artist == nil, case .artist = action { action = nil }
            }
        )
    }

    private func deleteAlbum() {
        // Каскад в SwiftData уберёт строки треков, но не mp3 — их мы копировали руками.
        // Песни, вышедшие ещё и синглом, не уходят: они возвращаются на свои синглы.
        // А песни с альбома, которые показывал этот сингл, остаются в альбоме.
        for track in album.sendSinglesHome() {
            audioPlayer.forget(track)
            AudioFileStore.remove(filename: track.filename)
        }

        let name = album.name
        modelContext.delete(album)
        toasts.removed("Deleted \(name)")
    }
}
