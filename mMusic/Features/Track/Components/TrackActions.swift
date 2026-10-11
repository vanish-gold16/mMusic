import SwiftData
import SwiftUI

/// Что открывает пункт меню трека. Листы, вопрос об удалении и переходы
/// живут у владельца меню (`trackActions`), а не в самих пунктах: меню
/// закрывается раньше, чем лист успевает открыться, и всё, что висело
/// на пункте, пропадает вместе с ним.
enum TrackAction: Hashable, Identifiable {
    case edit
    case lyrics
    case addToPlaylist
    case delete
    case album(Album)
    case artist(Artist)

    var id: Self { self }

    /// Переход, если это переход.
    var route: MusicRoute? {
        switch self {
        case .album(let album): .album(album)
        case .artist(let artist): .artist(artist)
        default: nil
        }
    }
}

/// Пункты меню трека — одни и те же в строке списка, на главной, в мини-плеере
/// и в очереди. Раньше у каждого места был свой набор, и то, что делалось
/// в одном, пропадало в другом: из строки нельзя было дойти до артиста,
/// с главной — вообще ни до чего.
struct TrackMenuItems: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    let track: Track
    @Binding var action: TrackAction?
    /// «Play next» и «Play after». В самой очереди у них другой смысл —
    /// там свои пункты, а эти прячутся.
    var showsEnqueue = true
    /// Заполняется только там, где трек показан в составе плейлиста.
    /// Без него в меню нет и пункта — удалять «из плейлиста» на странице альбома нечего.
    var onRemoveFromPlaylist: (() -> Void)? = nil
    /// Страница, на которой показан трек. Туда меню не ведёт:
    /// «Go to Album» на странице этого же альбома открыл бы её второй раз.
    var currentPage: MusicRoute? = nil

    var body: some View {
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
            action = .edit
        } label: {
            Label("Edit track", systemImage: "pencil")
        }
        Button {
            action = .lyrics
        } label: {
            Label(track.hasLyrics ? "Edit text" : "Add text", systemImage: "quote.bubble")
        }
        Button {
            action = .addToPlaylist
        } label: {
            Label("Add to a Playlist", systemImage: "text.badge.plus")
        }

        if showsEnqueue {
            Divider()

            Button {
                audioPlayer.enqueueNext([track])
                toasts.enqueuedNext(1)
            } label: {
                Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                audioPlayer.enqueueLast([track])
                toasts.enqueuedLast(1)
            } label: {
                Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
            }
        }

        Divider()

        if let album = track.album, currentPage != .album(album) {
            Button {
                action = .album(album)
            } label: {
                Label("Go to Album", systemImage: "music.note.square.stack")
            }
        }
        // Песня вышла ещё и синглом — до него тоже один шаг.
        if let single = track.single, currentPage != .album(single) {
            Button {
                action = .album(single)
            } label: {
                Label("Go to Single", systemImage: "record.circle")
            }
        }
        GoToArtistItems(artists: track.artists.filter { currentPage != .artist($0) }) { artist in
            action = .artist(artist)
        }

        Divider()

        if let onRemoveFromPlaylist {
            Button(role: .destructive) {
                onRemoveFromPlaylist()
                toasts.removed("Removed from the playlist")
            } label: {
                Label("Remove from playlist", systemImage: "minus.circle")
            }
        }

        // Раньше здесь было просто «Remove», и рядом с удалением из плейлиста
        // это читалось бы одинаково — а последствия разные.
        Button(role: .destructive) {
            action = .delete
        } label: {
            Label("Delete from library", systemImage: "trash")
        }
    }
}

extension View {

    /// Листы, вопрос об удалении и переходы для `TrackMenuItems`.
    ///
    /// `onNavigate` — для мест вне стопки навигации (мини-плеер, очередь):
    /// переход тогда делает тот, кто стопку держит. Без него экран
    /// открывается прямо отсюда.
    func trackActions(
        _ track: Track,
        action: Binding<TrackAction?>,
        onNavigate: ((MusicRoute) -> Void)? = nil
    ) -> some View {
        modifier(TrackActions(track: track, action: action, onNavigate: onNavigate))
    }
}

private struct TrackActions: ViewModifier {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts

    let track: Track
    @Binding var action: TrackAction?
    let onNavigate: ((MusicRoute) -> Void)?

    func body(content: Content) -> some View {
        navigation(content)
            .sheet(isPresented: isShowing(.edit)) {
                EditTrackView(track: track)
            }
            .sheet(isPresented: isShowing(.lyrics)) {
                LyricsEditorView(track: track)
            }
            .sheet(isPresented: isShowing(.addToPlaylist)) {
                AddToPlaylistView(tracks: [track])
            }
            .confirmationDialog(
                "Delete \"\(track.name)\"?",
                isPresented: isShowing(.delete),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The file is deleted from the library and from every playlist.")
            }
    }

    /// Переход — своим экраном в той же стопке или чужими руками, если стопки здесь нет.
    @ViewBuilder
    private func navigation(_ content: Content) -> some View {
        if let onNavigate {
            content
                .onChange(of: action) { _, action in
                    guard let route = action?.route else { return }
                    self.action = nil
                    onNavigate(route)
                }
        } else {
            content
                .navigationDestination(item: route) { route in
                    route.destination
                }
        }
    }

    /// Флажок для листа или вопроса — «открыто ли именно это». Закрыли лист —
    /// пункт сбрасывается, но только свой: другой мог уже успеть открыться.
    private func isShowing(_ shown: TrackAction) -> Binding<Bool> {
        Binding(
            get: { action == shown },
            set: { isShown in
                if !isShown, action == shown { action = nil }
            }
        )
    }

    private var route: Binding<MusicRoute?> {
        Binding(
            get: { action?.route },
            set: { route in
                if route == nil, action?.route != nil { action = nil }
            }
        )
    }

    private func delete() {
        let name = track.name
        // Номера в альбоме пересчитываются до удаления: после него ссылка
        // на трек уже невалидна, а дыру в нумерации закрыть нужно.
        track.album?.renumberTracks(excluding: track)

        audioPlayer.forget(track)
        AudioFileStore.remove(filename: track.filename)
        modelContext.delete(track)

        toasts.removed("Deleted \(name)")
    }
}
