import SwiftUI
import SwiftData

struct LibraryView: View {
    let columns = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]
    
    let columnsPinned = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]

    @Query(sort: \Album.addedAt, order: .reverse) private var albums: [Album]
    @Query(filter: #Predicate<Playlist> { $0.isPinned }) private var pinnedPlaylists: [Playlist]

    @State private var showCreateAlbum = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Spacer()
                
                if !pinnedPlaylists.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Pinned")
                            .font(.title)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: columnsPinned, spacing: 16) {
                            ForEach(pinnedPlaylists) { playlist in
                                PinnedPlaylistCell(playlist: playlist)
                            }
                        }
                    }
                }
                VStack(alignment: .leading) {
                    Text("Recently added")
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(albums) { album in
                            AlbumCell(album: album)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCreateAlbum = true
                    } label: {
                        Label("New album", systemImage: "music.note.square.stack")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    NavigationLink(destination: PlaylistsView()) {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    NavigationLink(destination: AlbumsView()) {
                        Label("Albums", systemImage: "square.stack")
                    }
                    NavigationLink(destination: ArtistsView()) {
                        Label("Artists", systemImage: "music.note")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
            }
        }
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView()
        }
        .navigationTitle("Library")
    }

}
