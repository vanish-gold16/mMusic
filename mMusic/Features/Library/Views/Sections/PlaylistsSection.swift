import SwiftData
import SwiftUI

/// Плейлисты одним списком: закреплённые сверху, остальные следом.
/// Отдельной полки «Pinned» больше нет — она дублировала тот же список.
///
/// В конце — пунктирный слот нового плейлиста, как «Add music» в самом плейлисте:
/// создать его можно и из «+» наверху, но там, где кончается список, — нагляднее.
struct PlaylistsSection: View {

    @Query(sort: \Playlist.name) private var playlists: [Playlist]

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
                PlaylistLink(playlist: playlist)
            }

            DashedSlot(title: "New playlist", cornerRadius: 28) {
                showCreatePlaylist = true
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
}
