import SwiftUI
import SwiftData

/// Новый плейлист — его будущая страница: веер, в котором главную карту
/// выбирают нажатием, а за ней выглядывают обложки добавленных треков; имя,
/// описание, треки и пунктирный слот «Add music». Создаётся кнопкой внизу.
struct CreatePlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var audioPlayer
    
    @State private var showTrackPicker = false

    @State private var playlist = Playlist(name: "", items: [])
    @State private var artworkData: Data?
    /// Цвета передней обложки — их отдаёт шапка, когда разберёт веер.
    @State private var palette: CoverPalette?

    /// Своя обложка ещё лежит отдельно от плейлиста — до создания он не в базе.
    private var fanSources: [Data] {
        Array(([artworkData].compactMap { $0 } + playlist.fanCovers).prefix(3))
    }

    private var trimmedName: String {
        playlist.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let tracks = playlist.orderedTracks

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    PlaylistFormHeader(
                        artworkData: $artworkData,
                        name: $playlist.name,
                        description: $playlist.playlistDescription,
                        fanSources: fanSources,
                        passport: playlist.summary(includingArtists: true),
                        palette: $palette
                    )
                    .padding(.top, 8)

                    RecordFormSection("Tracks", detail: tracks.isEmpty ? "" : "\(tracks.count)") {
                        EmptyView()
                    }
                    .padding(.top, 24)

                    ForEach(tracks) { track in
                        TrackCell(track: track, queue: tracks, leadingStyle: .artwork, showDuration: true)
                    }

                    DashedSlot(title: tracks.isEmpty ? "Add the first tracks" : "Add music", isLarge: tracks.isEmpty) {
                        showTrackPicker = true
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                createButton
            }
            .containerBackground(for: .navigation) {
                CoverAura(palette: palette, breathes: false)
            }
            // Всё в цвет обложки. Строго до `.toolbar` и листов: выбор музыки
            // остаётся в цвете приложения.
            .tint(palette?.accent ?? audioPlayer.accent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTrackPicker) {
                TrackPickerView(playlist: playlist)
            }
        }
    }

    private var createButton: some View {
        Button {
            create()
        } label: {
            Label("Create playlist", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        // Плейлист без имени в библиотеке не найти и не отличить от соседей.
        .disabled(trimmedName.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func create() {
        playlist.artwork = artworkData
        modelContext.insert(playlist)
        dismiss()
    }
}
