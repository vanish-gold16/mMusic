import SwiftData
import SwiftUI

/// Всё, что отмечено звездой. Флаги `isFavourite` были у трека и альбома давно,
/// но показать их было негде.
struct FavouritesView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    @Query(filter: #Predicate<Track> { $0.isFavourite }, sort: \Track.name) private var tracks: [Track]
    @Query(filter: #Predicate<Album> { $0.isFavourite }, sort: \Album.name) private var albums: [Album]
    @Query(filter: #Predicate<Playlist> { $0.isFavourite }, sort: \Playlist.name) private var playlists: [Playlist]

    private let columns = [GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top)]

    private var isEmpty: Bool {
        tracks.isEmpty && albums.isEmpty && playlists.isEmpty
    }

    var body: some View {
        Group {
            if isEmpty {
                ContentUnavailableView(
                    "Nothing favourited",
                    systemImage: "star",
                    description: Text("Tap the star on a track, album or playlist.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !tracks.isEmpty {
                    playButtons

                    section("Tracks") {
                        ForEach(tracks) { track in
                            TrackCell(track: track, queue: tracks, leadingStyle: .artwork)
                        }
                    }
                }

                if !albums.isEmpty {
                    section("Albums") {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(albums) { album in
                                AlbumCell(album: album)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if !playlists.isEmpty {
                    section("Playlists") {
                        ForEach(playlists) { playlist in
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

    private var playButtons: some View {
        HStack {
            Button {
                audioPlayer.play(tracks)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.glassProminent)

            Button {
                audioPlayer.playShuffled(tracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal)
            content()
        }
    }
}
