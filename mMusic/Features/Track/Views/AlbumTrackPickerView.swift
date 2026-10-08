import SwiftData
import SwiftUI

/// Сбор альбома из треков, которые уже есть в библиотеке.
///
/// Порядок выбора становится порядком треков в альбоме, поэтому у выбранных строк
/// стоит номер — иначе непонятно, почему после сохранения они встали именно так.
struct AlbumTrackPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var audioPlayer

    @Query private var tracks: [Track]

    @State private var selectedTab: TrackPickerTab = .recent
    @State private var searchText = ""
    /// Показывать только треки, которым альбом ещё не назначен. Пригодилось после
    /// восстановления библиотеки: собирать альбом заново проще, когда чужие треки
    /// не мешаются под руками.
    @State private var showsUnassignedOnly = false

    /// Альбом, который собираем. Пустой массив — альбома ещё нет, идёт создание.
    var album: [Album]
    @Binding var addedTracks: [TrackDraft]

    private var currentAlbum: Album? { album.first }

    /// «TO OUTRUN  ·  3 PICKED». У альбома, который ещё создают, имени нет.
    private var passport: String {
        let name = currentAlbum?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return [
            name.isEmpty ? "TO THE NEW ALBUM" : "TO \(name.uppercased())",
            addedTracks.isEmpty ? nil : "\(addedTracks.count) PICKED",
        ]
        .compactMap { $0 }
        .joined(separator: "  ·  ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    TrackPickerMasthead(passport: passport, tab: $selectedTab) {
                        // Фильтр — выключатель с лампой, как кнопки панели
                        // в плеере: горит — список сужен.
                        PanelSwitch(title: "Without album", isOn: showsUnassignedOnly, accent: audioPlayer.accent) {
                            withAnimation(.snappy) { showsUnassignedOnly.toggle() }
                        }
                    }
                    .padding(.bottom, 12)

                    if visibleTracks.isEmpty {
                        LibraryEmptyState(text: emptyText)
                    } else {
                        list
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Track or artist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetActionButton(.done) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        switch selectedTab {
        case .recent:
            ForEach(recentTracks) { track in
                cell(for: track)
            }
        case .genre:
            ForEach(genreGroups, id: \.genre) { group in
                CrateDivider(title: group.genre.rawValue.uppercased(), detail: "\(group.tracks.count)", size: 22)
                    .padding(.horizontal)
                    .padding(.top, 8)

                ForEach(group.tracks) { track in
                    cell(for: track)
                }
            }
        }
    }

    private func cell(for track: Track) -> some View {
        AlbumTrackPickCell(
            track: track,
            addedTracks: $addedTracks,
            currentAlbum: currentAlbum
        )
    }

    /// Пустой список объясняет, почему он пустой: поиск, фильтр или пустая библиотека.
    private var emptyText: String {
        if !searchText.isEmpty { return "Nothing matches" }
        if showsUnassignedOnly { return "Every track already belongs to an album" }
        return "Import music from the Library tab"
    }

    // MARK: - Что показываем

    private var recentTracks: [Track] {
        visibleTracks.sorted { $0.addedAt > $1.addedAt }
    }

    private var genreGroups: [(genre: Genre, tracks: [Track])] {
        Dictionary(grouping: visibleTracks, by: \.genre)
            .map { (genre: $0.key, tracks: $0.value.sorted { $0.addedAt > $1.addedAt }) }
            .sorted { $0.genre.rawValue < $1.genre.rawValue }
    }

    private var visibleTracks: [Track] {
        var result = tracks

        if showsUnassignedOnly {
            // Уже выбранные остаются видимыми при любом фильтре: иначе снять
            // галочку было бы негде.
            result = result.filter { track in
                track.album == nil
                    || track.album?.persistentModelID == currentAlbum?.persistentModelID
                    || addedTracks.contains { ($0.sourceTrack ?? $0.existingTrack) == track.persistentModelID }
            }
        }

        guard !searchText.isEmpty else { return result }

        return result.filter { track in
            track.name.localizedCaseInsensitiveContains(searchText)
                || track.artists.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
