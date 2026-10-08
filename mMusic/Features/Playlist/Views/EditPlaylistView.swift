import SwiftData
import SwiftUI

/// Правка плейлиста — его же страница, только всё в ней меняется: веер
/// с главной обложкой, имя, описание и список треков, из которого их смахивают.
/// Изменения пишутся сразу, «DONE» просто закрывает лист.
struct EditPlaylistView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var showTrackPicker = false
    /// Цвета передней обложки — их отдаёт шапка, когда разберёт веер.
    @State private var palette: CoverPalette?
    
    @Bindable var playlist: Playlist
    
    var body: some View {
        let tracks = playlist.orderedTracks

        NavigationStack {
            List {
                PlaylistFormHeader(
                    artworkData: $playlist.artwork,
                    name: $playlist.name,
                    description: $playlist.playlistDescription,
                    fanSources: playlist.fanCovers,
                    passport: playlist.summary(includingArtists: true),
                    palette: $palette
                )
                .padding(.top, 8)
                .bareRow()

                RecordFormSection("Tracks", detail: tracks.isEmpty ? "" : "\(tracks.count)") {
                    if !tracks.isEmpty {
                        RecordHint("Swipe a track to take it out")
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .bareRow()

                ForEach(tracks) { track in
                    TrackCell(
                        track: track,
                        queue: tracks,
                        leadingStyle: .artwork,
                        showDuration: true,
                        onRemoveFromPlaylist: { remove(track) }
                    )
                    .bareRow()
                }
                .onDelete { offsets in
                    removeTracks(at: offsets)
                }

                DashedSlot(title: tracks.isEmpty ? "Add the first tracks" : "Add music", isLarge: tracks.isEmpty) {
                    showTrackPicker = true
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .bareRow()
            }
            .listStyle(.plain)
            .listRowSpacing(8)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            // Всё в цвет обложки. Строго до `.toolbar` и листов: выбор музыки
            // остаётся в цвете приложения.
            .tint(palette?.accent ?? audioPlayer.accent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetActionButton(.done) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTrackPicker) {
                TrackPickerView(playlist: playlist)
            }
        }
    }

    /// Убирает трек из плейлиста, не трогая ни файл, ни запись в библиотеке:
    /// удаляется только связка `TrackPlaylistItem`.
    private func remove(_ track: Track) {
        guard let index = playlist.items
            .sorted(by: { $0.position < $1.position })
            .firstIndex(where: { $0.track.persistentModelID == track.persistentModelID })
        else { return }

        removeTracks(at: IndexSet(integer: index))
    }

    private func removeTracks(at offsets: IndexSet) {
        var items = playlist.items.sorted { $0.position < $1.position }

        for index in offsets where items.indices.contains(index) {
            modelContext.delete(items[index])
        }

        // Позиции пересчитываются, иначе в нумерации остаются дыры.
        items.remove(atOffsets: offsets)
        for (index, item) in items.enumerated() {
            item.position = index
        }
    }
}
