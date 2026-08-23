import SwiftData
import SwiftUI

struct SearchView: View {

    @State private var searchText: String = ""

    @Query private var tracks: [Track]
    @Query(sort: \Album.name) private var albums: [Album]
    @Query(sort: \Artist.name) private var artists: [Artist]
    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    private let albumColumns = [GridItem(.flexible(), alignment: .top),
                                GridItem(.flexible(), alignment: .top)]

    // Фильтруется в Swift, а не в #Predicate: имена артистов у трека и альбома —
    // вычисляемые свойства поверх связей, запрос до них не дотянется.
    private var matchedTracks: [Track] {
        filtered(tracks) { [$0.name] + $0.artistNames }
    }
    private var matchedAlbums: [Album] {
        filtered(albums) { [$0.name] + $0.artistNames }
    }
    private var matchedArtists: [Artist] {
        filtered(artists) { [$0.name] }
    }
    private var matchedPlaylists: [Playlist] {
        filtered(playlists) { [$0.name, $0.playlistDescription] }.byLastPlayed
    }

    private var hasResults: Bool {
        !matchedTracks.isEmpty || !matchedAlbums.isEmpty
            || !matchedArtists.isEmpty || !matchedPlaylists.isEmpty
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        Group {
            if query.isEmpty {
                ContentUnavailableView(
                    "Search your library",
                    systemImage: "magnifyingglass",
                    description: Text("Tracks, albums, artists and playlists.")
                )
            } else if hasResults {
                results
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText)
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !matchedTracks.isEmpty {
                    section("Tracks") {
                        ForEach(matchedTracks) { track in
                            TrackCell(track: track, queue: matchedTracks, leadingStyle: .artwork)
                        }
                    }
                }

                if !matchedAlbums.isEmpty {
                    section("Albums") {
                        LazyVGrid(columns: albumColumns, spacing: 16) {
                            ForEach(matchedAlbums) { album in
                                AlbumCell(album: album)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if !matchedArtists.isEmpty {
                    section("Artists") {
                        ForEach(matchedArtists) { artist in
                            ArtistsTabArtistCell(artist: artist)
                                .padding(.horizontal)
                        }
                    }
                }

                if !matchedPlaylists.isEmpty {
                    section("Playlists") {
                        ForEach(matchedPlaylists) { playlist in
                            NavigationLink {
                                PlaylistView(playlist: playlist)
                            } label: {
                                PlaylistCell(playlist: playlist)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            content()
        }
    }

    /// Совпадение — если хоть одно из полей содержит запрос, без учёта регистра.
    private func filtered<T>(_ items: [T], fields: (T) -> [String]) -> [T] {
        guard !query.isEmpty else { return [] }
        return items.filter { item in
            fields(item).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}
