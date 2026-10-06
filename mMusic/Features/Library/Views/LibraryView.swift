import SwiftData
import SwiftUI

/// Вся библиотека на одном экране. Раньше это были четыре отдельных экрана,
/// в которые вели два одинаковых бургер-меню — из Home и отсюда же.
///
/// Наверху — указатель разделов крупными словами (`LibraryMasthead`), как
/// шапка главной; под ним открытый раздел. Сверху светится цвет того, что
/// играет, — та же комната, что на главной, только спокойнее: здесь ищут,
/// а не слушают.
struct LibraryView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    @AppStorage(AppSettings.librarySection) private var section: LibrarySection = .albums
    @AppStorage(AppSettings.albumSort) private var albumSort: AlbumSort = .dateAdded

    @State private var showCreateAlbum = false
    @State private var showCreatePlaylist = false
    @State private var showImport = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                LibraryMasthead(section: $section, albumSort: $albumSort)
                    .padding(.top, 4)

                switch section {
                case .albums:
                    AlbumsSection(sort: albumSort)
                case .playlists:
                    PlaylistsSection()
                case .artists:
                    ArtistsSection()
                case .smart:
                    SmartPlaylistsSection()
                }
            }
            .padding(.bottom, 24)
        }
        // `containerBackground`, а не `background`: у экрана в навигации своя
        // непрозрачная подложка.
        .containerBackground(for: .navigation) {
            CoverAura(palette: audioPlayer.currentTrack == nil ? nil : audioPlayer.palette, breathes: false)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
}
