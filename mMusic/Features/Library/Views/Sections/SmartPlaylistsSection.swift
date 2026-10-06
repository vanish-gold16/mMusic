import SwiftData
import SwiftUI

/// Список автоподборок. Пустые не показываются — карточка «0 треков» только мешает.
struct SmartPlaylistsSection: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @Query private var tracks: [Track]

    /// Подборки вместе с их треками: считаются один раз на весь список,
    /// а не заново в каждой строке и в каждом пункте меню.
    private var available: [(playlist: SmartPlaylist, tracks: [Track])] {
        SmartPlaylist.allCases
            .map { ($0, $0.tracks(from: tracks)) }
            .filter { !$0.1.isEmpty }
    }

    var body: some View {
        let available = available

        if available.isEmpty {
            LibraryEmptyState(text: "Nothing to collect yet")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(available, id: \.playlist.id) { entry in
                    NavigationLink {
                        SmartPlaylistView(playlist: entry.playlist)
                    } label: {
                        SmartPlaylistCell(playlist: entry.playlist, tracks: entry.tracks)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(entry.playlist, tracks: entry.tracks) }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func menu(_ playlist: SmartPlaylist, tracks: [Track]) -> some View {
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

        Divider()

        Button {
            let kept = playlist.keep(tracks, in: modelContext)
            toasts.show("Kept as \(kept.name)", systemImage: "text.badge.plus")
        } label: {
            Label("Keep as playlist", systemImage: "text.badge.plus")
        }
    }
}
