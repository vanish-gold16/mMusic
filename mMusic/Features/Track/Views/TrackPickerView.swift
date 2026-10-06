import SwiftData
import SwiftUI

/// Музыка в плейлист из библиотеки. Выбор сразу кладёт трек в плейлист,
/// повторное нажатие убирает, — поэтому кнопка у листа одна: «done».
///
/// Наверху «Add music», куда добавляем и вкладки словами; в жанрах треки
/// разложены за разделителями, как пластинки в ящике.
struct TrackPickerView: View {

    @Environment(\.dismiss) private var dismiss

    @Query private var tracks: [Track]

    @State private var selectedTab: TrackPickerTab = .recent
    @State private var searchText = ""

    var playlist: Playlist

    private var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter { track in
            track.name.localizedCaseInsensitiveContains(searchText)
                || track.artists.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var recentTracks: [Track] {
        filteredTracks.sorted { $0.addedAt > $1.addedAt }
    }

    private var genreGroups: [(genre: Genre, tracks: [Track])] {
        Dictionary(grouping: filteredTracks, by: \.genre)
            .map { (genre: $0.key, tracks: $0.value.sorted { $0.addedAt > $1.addedAt }) }
            .sorted { $0.genre.rawValue < $1.genre.rawValue }
    }

    /// «TO NIGHT DRIVES  ·  12 TRACKS». У плейлиста, который ещё создают,
    /// имени может не быть.
    private var passport: String {
        let name = playlist.name.trimmingCharacters(in: .whitespaces)
        let count = playlist.items.count
        return [
            name.isEmpty ? "TO THE NEW PLAYLIST" : "TO \(name.uppercased())",
            count == 0 ? nil : (count == 1 ? "1 TRACK" : "\(count) TRACKS"),
        ]
        .compactMap { $0 }
        .joined(separator: "  ·  ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    TrackPickerMasthead(passport: passport, tab: $selectedTab)
                        .padding(.bottom, 12)

                    if filteredTracks.isEmpty {
                        LibraryEmptyState(text: searchText.isEmpty ? "Import music from the Library tab" : "Nothing matches")
                    } else {
                        switch selectedTab {
                        case .recent:
                            ForEach(recentTracks) { track in
                                PlaylistTrackPickCell(track: track, playlist: playlist)
                            }
                        case .genre:
                            ForEach(genreGroups, id: \.genre) { group in
                                CrateDivider(title: group.genre.rawValue.uppercased(), detail: "\(group.tracks.count)", size: 22)
                                    .padding(.horizontal)
                                    .padding(.top, 8)

                                ForEach(group.tracks) { track in
                                    PlaylistTrackPickCell(track: track, playlist: playlist)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Track or artist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
