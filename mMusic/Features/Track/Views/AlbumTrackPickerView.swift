import SwiftData
import SwiftUI

/// Сбор альбома из треков, которые уже есть в библиотеке.
///
/// Порядок выбора становится порядком треков в альбоме, поэтому у выбранных строк
/// стоит номер — иначе непонятно, почему после сохранения они встали именно так.
struct AlbumTrackPickerView: View {

    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        NavigationStack {
            Group {
                if visibleTracks.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .safeAreaInset(edge: .top) { filters }
            .navigationTitle("Add music")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Track or artist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                switch selectedTab {
                case .recent:
                    ForEach(recentTracks) { track in
                        cell(for: track)
                    }
                case .genre:
                    ForEach(genreGroups, id: \.genre) { group in
                        SectionLabel(group.genre.rawValue)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        ForEach(group.tracks) { track in
                            cell(for: track)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func cell(for track: Track) -> some View {
        AlbumTrackPickCell(
            track: track,
            addedTracks: $addedTracks,
            currentAlbum: currentAlbum
        )
    }

    /// Строка состояния над списком: чем список сейчас сужен и сколько уже набрано.
    private var filters: some View {
        VStack(spacing: 10) {
            Picker("Section", selection: $selectedTab) {
                ForEach(TrackPickerTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy) { showsUnassignedOnly.toggle() }
                } label: {
                    Label("Without album", systemImage: showsUnassignedOnly ? "checkmark" : "line.3.horizontal.decrease")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .background(
                    showsUnassignedOnly ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08),
                    in: Capsule()
                )

                Spacer()

                Text(addedTracks.isEmpty ? "Nothing picked" : "\(addedTracks.count) picked")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var empty: some View {
        Group {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if showsUnassignedOnly {
                ContentUnavailableView(
                    "No free tracks",
                    systemImage: "square.stack",
                    description: Text("Every track already belongs to an album. Turn off the filter to move one here.")
                )
            } else {
                ContentUnavailableView(
                    "Library is empty",
                    systemImage: "music.note",
                    description: Text("Import music from the Library tab.")
                )
            }
        }
        .frame(maxHeight: .infinity)
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
                    || addedTracks.contains { $0.sourceTrack == track.persistentModelID }
            }
        }

        guard !searchText.isEmpty else { return result }

        return result.filter { track in
            track.name.localizedCaseInsensitiveContains(searchText)
                || track.artists.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
