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
    /// Строка авторов под именем. nil — все авторы альбома; пустая — строки нет.
    /// На странице артиста его самого под каждым конвертом не пишут.
    var byline: String? = nil
    /// Треки, где звучит гость, — на странице артиста в разделе Featured on.
    /// Их кольца на диске светятся, а если гость не на всём альбоме,
    /// под конвертом написано, на каких.
    var guestTracks: [Track] = []
    /// Мелкая ячейка для сетки в три колонки — синглы на странице артиста.
    var isCompact = false

    /// У сингла сюда входит и его песня, живущая в альбоме: см. `Album.tracklist`.
    private var sortedTracks: [Track] {
        album.tracklist
    }

    /// Паспорт одной строкой: «LP  ·  2024», у двойного — «2×LP  ·  2024».
    /// Год — если дата выхода известна.
    private var passport: String {
        var parts = [album.formatLabel]
        if let release = album.release {
            parts.append(String(Calendar.current.component(.year, from: release)))
        }
        return parts.joined(separator: "  ·  ").uppercased()
    }

    private var artistsLine: String {
        byline ?? album.artistNames.joined(separator: ", ")
    }

    /// Кольца гостевых треков по пластинкам — в том виде, в каком их ждёт конверт.
    private var markedRings: [Set<Int>] {
        guard !guestTracks.isEmpty else { return [] }
        let ids = Set(guestTracks.map(\.persistentModelID))

        return album.tracklistDiscs.map { disc in
            Set(disc.indices.filter { ids.contains(disc[$0].persistentModelID) })
        }
    }

    /// На каких треках гость. Только если не на всех: у сингла имя трека —
    /// это и есть имя альбома, а «все треки» видно по кольцам.
    private var guestNote: String? {
        guard !guestTracks.isEmpty, guestTracks.count < album.tracklist.count else { return nil }
        return guestTracks.map(\.name).joined(separator: ", ")
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
        // Играет трек из этого альбома. Очередь, как у плейлиста, проверять
        // незачем: альбом у трека один. Выдвинута та пластинка, что играет.
        let playing = album.position(of: audioPlayer.currentTrack)
        let isCurrent = playing != nil

        return VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            // `isPlaying` и акцент читаются только у играющего альбома: иначе
            // каждая ячейка сетки перерисовывалась бы на каждой паузе.
            AlbumSleeve(
                cover: cover,
                type: album.type,
                discs: album.tracklistDiscs.map { $0.map(\.duration) },
                outDisc: playing?.disc,
                playing: playing,
                isPlaying: isCurrent && audioPlayer.isPlaying,
                accent: isCurrent ? audioPlayer.accent : .clear,
                marked: markedRings
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(album.name)
                    .font(.system(size: isCompact ? 17 : 21, weight: .heavy).width(.compressed))
                    .lineLimit(2)

                if !artistsLine.isEmpty {
                    Text(artistsLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let guestNote {
                    // Контурная звезда — та же, что у гостя в редакторе авторов.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "star")
                            .font(.caption2)
                            .accessibilityLabel("Guest on")
                        Text(guestNote)
                            .lineLimit(1)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

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
        // Песни, вышедшие ещё и синглом, не уходят: они возвращаются на свои синглы.
        // А песни с альбома, которые показывал этот сингл, остаются в альбоме.
        for track in album.sendSinglesHome() {
            audioPlayer.forget(track)
            AudioFileStore.remove(filename: track.filename)
        }

        let name = album.name
        modelContext.delete(album)
        toasts.removed("Deleted \(name)")
    }
    
}
