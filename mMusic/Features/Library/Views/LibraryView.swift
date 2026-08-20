import SwiftData
import SwiftUI

/// Вся библиотека на одном экране. Раньше это были четыре отдельных экрана,
/// в которые вели два одинаковых бургер-меню — из Home и отсюда же.
struct LibraryView: View {

    @State private var section: LibrarySection = .albums
    @State private var albumSort: AlbumSort = .dateAdded

    @State private var showCreateAlbum = false
    @State private var showCreatePlaylist = false
    @State private var showImport = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                Picker("Section", selection: $section) {
                    ForEach(LibrarySection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)

                switch section {
                case .albums:
                    AlbumsSection(sort: albumSort)
                case .playlists:
                    PlaylistsSection()
                case .artists:
                    ArtistsSection()
                case .favourites:
                    FavouritesSection()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Library")
        .toolbar {
            if section == .albums {
                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                addMenu
            }
        }
        .sheet(isPresented: $showCreateAlbum) {
            CreateAlbumView()
        }
        .sheet(isPresented: $showCreatePlaylist) {
            CreatePlaylistView()
        }
        .sheet(isPresented: $showImport) {
            NavigationStack {
                DownloadView()
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                showImport = true
            } label: {
                Label("Import music", systemImage: "square.and.arrow.down")
            }

            Divider()

            Button {
                showCreateAlbum = true
            } label: {
                Label("New album", systemImage: "square.stack")
            }
            Button {
                showCreatePlaylist = true
            } label: {
                Label("New playlist", systemImage: "music.note.list")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $albumSort) {
                ForEach(AlbumSort.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}
