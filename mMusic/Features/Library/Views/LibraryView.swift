import SwiftUI
import SwiftData

struct LibraryView: View {
    let columns = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]
    
    let columnsPinned = [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)]

    @Query(sort: \Album.addedAt, order: .reverse) private var albums: [Album]
    @Query(filter: #Predicate<Playlist> { $0.isPinned }) private var pinnedPlaylists: [Playlist]

    @State private var showCreateAlbum = false
    
    @State private var selectedCategory: LibraryCategory = .playlists

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Spacer()
                
                ForEach(LibraryCategory.allCases, id: \.self) { category in
                    NavigationLink(destination: destinationView(for: category)) {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
                    .animation(.easeOut, value: selectedCategory)
                }
                
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
                    .animation(.easeOut, value: selectedCategory)
                    NavigationLink(destination: AlbumsView()) {
                        Label("Albums", systemImage: "square.stack")
                    }
                    .animation(.easeOut, value: selectedCategory)
                    NavigationLink(destination: ArtistsView()) {
                        Label("Artists", systemImage: "music.note")
                    }
                    .animation(.easeOut, value: selectedCategory)
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
    
    @ViewBuilder
    func destinationView (for category: LibraryCategory) -> some View {
        switch category {
        case .playlists: PlaylistsView()
        case .albums: AlbumsView()
        case .artists: ArtistsView()
        }
    }
}
