import SwiftData
import SwiftUI

/// Всё, что отмечено звездой: треки, альбомы, плейлисты.
struct FavouritesSection: View {

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
        if isEmpty {
            LibraryEmptyState(text: "Nothing favourited yet")
        } else {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !tracks.isEmpty {
                    playButtons

                    SectionLabel("Tracks")
                    ForEach(tracks) { track in
                        TrackCell(track: track, queue: tracks, leadingStyle: .artwork)
                    }
                }

                if !albums.isEmpty {
                    SectionLabel("Albums")
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(albums) { album in
                            AlbumCell(album: album)
                        }
                    }
                    .padding(.horizontal)
                }

                if !playlists.isEmpty {
                    SectionLabel("Playlists")
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
    }

    private var playButtons: some View {
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
}
