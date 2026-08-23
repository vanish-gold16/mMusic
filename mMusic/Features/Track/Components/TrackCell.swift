import SwiftData
import SwiftUI

struct TrackCell: View {
    
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(ToastCenter.self) private var toasts
    
    @State private var showEditTrack: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var albumToShow: Album?
    @State private var showAddToPlaylist = false

    enum LeadingStyle {
        case number
        case artwork
    }

    var track: Track
    var queue: [Track] = []
    var leadingStyle: LeadingStyle = .number
    /// В обычных списках счётчик — лишний шум, поэтому включается точечно.
    var showPlayCount: Bool = false
    /// Заполняется только там, где трек показан в составе плейлиста.
    /// Без него в меню нет и пункта — удалять «из плейлиста» на странице альбома нечего.
    var onRemoveFromPlaylist: (() -> Void)?

    private var isCurrent: Bool {
        audioPlayer.currentTrack?.id == track.id
    }

    var body: some View {
        HStack {
            switch leadingStyle {
            case .number:
                if isCurrent {
                    EqualizerView(level: audioPlayer.level)
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                } else {
                    Text("\(track.position + 1)")
                        .frame(width: 40, height: 40)
                }
            case .artwork:
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if let data = track.displayArtwork, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .overlay {
                        if isCurrent {
                            Color.black.opacity(0.4)
                            EqualizerView(level: audioPlayer.level)
                                .foregroundStyle(.white)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            VStack(alignment: .leading) {
                Text(track.name)
                    .bold()
                    .lineLimit(1)
                Text(track.artistNames.joined(separator: ", "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            if track.isFavourite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }

            if showPlayCount, track.playCount > 0 {
                Label("\(track.playCount)", systemImage: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            }

            Menu {
                ControlGroup {
                    Button {
                        track.isFavourite.toggle()
                    } label: {
                        Label("Favourite", systemImage: track.isFavourite ? "star.fill" : "star")
                    }
                    ShareLink(item: AudioFileStore.url(for: track.filename)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

                Divider()
                
                Button {
                    showEditTrack = true
                } label: {
                    Label("Edit track", systemImage: "pencil")
                }
                
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("Add to a Playlist", systemImage: "text.badge.plus")
                }
                
                Divider()

                Button {
                    audioPlayer.enqueueNext([track])
                    toasts.enqueuedNext(1)
                } label: {
                    Label("Play next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button {
                    audioPlayer.enqueueLast([track])
                    toasts.enqueuedLast(1)
                } label: {
                    Label("Play after", systemImage: "text.line.last.and.arrowtriangle.forward")
                }

                Divider()
                
                if track.album != nil {
                    Button {
                        albumToShow = track.album
                    } label: {
                        Label("Go to Album", systemImage: "music.note.square.stack")
                    }
                }
                
                Divider()

                if let onRemoveFromPlaylist {
                    Button(role: .destructive) {
                        onRemoveFromPlaylist()
                        toasts.removed("Removed from the playlist")
                    } label: {
                        Label("Remove from playlist", systemImage: "minus.circle")
                    }
                }

                // Раньше здесь было просто «Remove», и рядом с удалением из плейлиста
                // это читалось бы одинаково — а последствия разные.
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete from library", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // Играющая строка красится стеклом, а не отдельной плашкой: видно сразу,
        // и цвет тот же, что у обложки.
        .glassEffect(isCurrent ? .regular.tint(audioPlayer.accent.opacity(0.28)) : .regular)
        .padding(.horizontal)
        .onTapGesture {
            let list = queue.isEmpty ? [track] : queue  // ← подумай, не перепутал ли порядок
            let index = list.firstIndex { $0.id == track.id } ?? 0
            audioPlayer.play(list, startingAt: index)
        }
        .sheet(isPresented: $showEditTrack) {
            EditTrackView(track: track)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistView(tracks: [track])
        }
        .navigationDestination(item: $albumToShow) { album in
            AlbumView(album: album)
        }
        .confirmationDialog(
            "Delete \"\(track.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                let name = track.name
                // Номера в альбоме пересчитываются до удаления: после него ссылка
                // на трек уже невалидна, а дыру в нумерации закрыть нужно.
                track.album?.renumberTracks(excluding: track)

                audioPlayer.forget(track)
                AudioFileStore.remove(filename: track.filename)
                modelContext.delete(track)

                toasts.removed("Deleted \(name)")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The file is deleted from the library and from every playlist.")
        }
    }
}
