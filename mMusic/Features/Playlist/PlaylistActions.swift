import SwiftData
import SwiftUI

/// Что открывает пункт меню плейлиста. Как у трека (`TrackAction`), листы
/// и вопрос живут у владельца меню, а не в пунктах.
enum PlaylistAction: Hashable, Identifiable {
    case edit
    case addMusic
    case delete

    var id: Self { self }
}

/// Пункты меню плейлиста — одни и те же в библиотеке, в поиске и на странице
/// самого плейлиста. Раньше в поиске меню не было вовсе, а закрепить плейлист
/// можно было только из библиотеки.
struct PlaylistMenuItems: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    let playlist: Playlist
    @Binding var action: PlaylistAction?
    /// На странице плейлиста в меню есть ещё сортировка: переставлять
    /// порядок вслепую, из списка, незачем.
    var isOnItsPage = false

    var body: some View {
        let tracks = playlist.orderedTracks

        ControlGroup {
            Button {
                playlist.isPinned.toggle()
            } label: {
                Label(playlist.isPinned ? "Unpin" : "Pin", systemImage: playlist.isPinned ? "pin.fill" : "pin")
            }
            Button {
                playlist.isFavourite.toggle()
            } label: {
                Label("Favourite", systemImage: playlist.isFavourite ? "star.fill" : "star")
            }
            ShareLink(items: tracks.map { AudioFileStore.url(for: $0.filename) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        if !tracks.isEmpty {
            Button {
                playlist.markPlayed()
                audioPlayer.play(tracks)
            } label: {
                Label("Play", systemImage: "play")
            }
            Button {
                playlist.markPlayed()
                audioPlayer.playShuffled(tracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
            }

            Divider()
        }

        Button {
            action = .addMusic
        } label: {
            Label("Add music", systemImage: "plus")
        }
        Button {
            action = .edit
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        if isOnItsPage, !tracks.isEmpty {
            Menu {
                ForEach(PlaylistSort.allCases) { option in
                    Button {
                        sort(by: option)
                    } label: {
                        Label(option.rawValue, systemImage: option.systemImage)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }

        if !tracks.isEmpty {
            Divider()

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
        }

        Divider()

        Button(role: .destructive) {
            action = .delete
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    /// Переписывает позиции раз и навсегда: дальше порядок снова ручной.
    private func sort(by option: PlaylistSort) {
        for (index, item) in option.sorted(playlist.items).enumerated() {
            item.position = index
        }
    }
}

extension View {

    /// Листы и вопрос об удалении для `PlaylistMenuItems`.
    ///
    /// `onLeave` — для страницы самого плейлиста: удалённый плейлист нельзя
    /// оставлять на экране, поэтому сначала уходим с него.
    func playlistActions(
        _ playlist: Playlist,
        action: Binding<PlaylistAction?>,
        onLeave: (() -> Void)? = nil
    ) -> some View {
        modifier(PlaylistActions(playlist: playlist, action: action, onLeave: onLeave))
    }
}

private struct PlaylistActions: ViewModifier {

    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts

    let playlist: Playlist
    @Binding var action: PlaylistAction?
    let onLeave: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isShowing(.edit)) {
                EditPlaylistView(playlist: playlist)
            }
            .sheet(isPresented: isShowing(.addMusic)) {
                TrackPickerView(playlist: playlist)
            }
            .confirmationDialog(
                "Delete \"\(playlist.name)\"?",
                isPresented: isShowing(.delete),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    let name = playlist.name
                    deleteAfterLeaving(onLeave) {
                        modelContext.delete(playlist)
                        toasts.removed("Deleted \(name)")
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The playlist is deleted. Its tracks stay in the library.")
            }
    }

    private func isShowing(_ shown: PlaylistAction) -> Binding<Bool> {
        Binding(
            get: { action == shown },
            set: { isShown in
                if !isShown, action == shown { action = nil }
            }
        )
    }
}

/// Плейлист в списке — строка-ссылка на его страницу с тем же меню
/// по долгому нажатию. Одна на библиотеку и поиск.
struct PlaylistLink: View {

    let playlist: Playlist

    @State private var action: PlaylistAction?

    var body: some View {
        NavigationLink {
            PlaylistView(playlist: playlist)
        } label: {
            PlaylistCell(playlist: playlist)
        }
        .buttonStyle(.plain)
        .contextMenu {
            PlaylistMenuItems(playlist: playlist, action: $action)
        }
        .playlistActions(playlist, action: $action)
    }
}
