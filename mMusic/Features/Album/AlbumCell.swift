import SwiftData
import SwiftUI

/// Альбом в сетке: конверт с выглядывающей пластинкой (`AlbumSleeve`), под ним
/// сжатое имя, авторы и паспорт «LP · 2024». Та же типографика, что у плейлистов,
/// но вместо веера карт — один конверт: альбом — это одна вещь, а не подборка.
struct AlbumCell: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) var audioPlayer
    @Environment(ToastCenter.self) private var toasts

    @State private var showDeleteConfirmation = false
    @State private var showAddToPlaylist = false

    /// Уменьшенная обложка — декодируется в `.task`, а не в `body`: полноразмерная
    /// весит мегабайты, а `body` пересчитывается на каждой смене трека.
    @State private var cover: UIImage?

    let album: Album

    private var sortedTracks: [Track] {
        album.tracks.sorted { $0.position < $1.position }
    }

    /// Паспорт одной строкой: «LP  ·  2024». Год — если дата выхода известна.
    private var passport: String {
        var parts = [album.type.rawValue]
        if let release = album.release {
            parts.append(String(Calendar.current.component(.year, from: release)))
        }
        return parts.joined(separator: "  ·  ").uppercased()
    }
    
    var body: some View {
        NavigationLink {
            AlbumView(album: album)
        } label: {
            label
        }
        .contextMenu {
            VStack {
                Button {
                    album.isFavourite.toggle()
                } label: {
                    Label("Favorite", systemImage: album.isFavourite ? "star.fill" : "star")
                }
                
                Divider()
                
                Button {
                    audioPlayer.play(sortedTracks)
                } label: {
                    Label("Play", systemImage: "play")
                }
                Button {
                    audioPlayer.playShuffled(sortedTracks)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                
                Divider()
                
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Add to playlist", systemImage: "text.badge.plus")
                }
                
                Divider()
                
                Button {
                    audioPlayer.enqueueNext(sortedTracks)
                    toasts.enqueuedNext(sortedTracks.count)
                } label: {
                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                
                Button {
                    audioPlayer.enqueueLast(sortedTracks)
                    toasts.enqueuedLast(sortedTracks.count)
                } label: {
                    Label("Play After", systemImage: "text.line.last.and.arrowtriangle.forward")
                }
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete album", systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: album.artwork?.count) {
            await loadCover()
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistView(tracks: sortedTracks)
        }
        .confirmationDialog(
            "Delete \"\(album.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteAlbum()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This album and all its tracks will be permanently deleted.")
        }
    }
    
    private var label: some View {
        let tracks = sortedTracks
        // Играет трек из этого альбома. Очередь, как у плейлиста, проверять
        // незачем: альбом у трека один.
        let currentIndex = tracks.firstIndex { $0.id == audioPlayer.currentTrack?.id }
        let isCurrent = currentIndex != nil

        return VStack(alignment: .leading, spacing: 10) {
            // `isPlaying` и акцент читаются только у играющего альбома: иначе
            // каждая ячейка сетки перерисовывалась бы на каждой паузе.
            AlbumSleeve(
                cover: cover,
                type: album.type,
                durations: tracks.map(\.duration),
                currentIndex: currentIndex,
                isPlaying: isCurrent && audioPlayer.isPlaying,
                accent: isCurrent ? audioPlayer.accent : .clear
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(album.name)
                    .font(.system(size: 21, weight: .heavy).width(.compressed))
                    .lineLimit(2)

                Text(album.artistNames.joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(passport)
                    if album.isFavourite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Favourite")
                    }
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    /// Конверт в сетке — около 135 pt, это ~400 px на экране @3x.
    private func loadCover() async {
        guard let data = album.artwork else {
            cover = nil
            return
        }

        let image = await Task.detached(priority: .utility) {
            UIImage.thumbnail(from: data, side: 400)
        }.value

        guard !Task.isCancelled else { return }
        cover = image
    }

    private func deleteAlbum() {
        // Каскад в SwiftData уберёт строки треков, но не mp3 — их мы копировали руками.
        for track in album.tracks {
            audioPlayer.forget(track)
            AudioFileStore.remove(filename: track.filename)
        }

        let name = album.name
        modelContext.delete(album)
        toasts.removed("Deleted \(name)")
    }
    
}
