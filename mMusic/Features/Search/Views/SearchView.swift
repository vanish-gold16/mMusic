import SwiftData
import SwiftUI

/// Поиск по всей фонотеке.
///
/// Шапка — как у библиотеки и главной: сжатое крупное слово. Пока запроса нет,
/// это «Search», а под ним — указатель жанров фонотеки, как таблички над
/// разделами в магазине: нажатие ищет по жанру. Когда запрос есть, крупно
/// напечатан сам запрос, а результаты лежат за разделителями ящика:
/// артисты, пластинки, треки, плейлисты.
struct SearchView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var searchText: String = ""

    @Query private var tracks: [Track]
    @Query(sort: \Album.name) private var albums: [Album]
    @Query private var artists: [Artist]
    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    private let albumColumns = [GridItem(.flexible(), spacing: 16, alignment: .top),
                                GridItem(.flexible(), spacing: 16, alignment: .top)]

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    /// Запрос — ровно название жанра. Тогда ищется и сам жанр: «Phonk» находит
    /// треки в жанре, а не только те, где это слово стоит в названии.
    private var genre: Genre? {
        Genre.allCases.first {
            $0.rawValue.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    /// Всё найденное разом: считается один раз на перерисовку, а не заново
    /// в шапке, в каждом разделе и в проверке «нашлось ли что-то».
    private struct Results {
        var artists: [Artist] = []
        var albums: [Album] = []
        var tracks: [Track] = []
        var playlists: [Playlist] = []

        var isEmpty: Bool {
            artists.isEmpty && albums.isEmpty && tracks.isEmpty && playlists.isEmpty
        }
    }

    // Фильтруется в Swift, а не в #Predicate: имена артистов у трека и альбома —
    // вычисляемые свойства поверх связей, запрос до них не дотянется.
    private func search() -> Results {
        guard !query.isEmpty else { return Results() }
        let genre = genre

        return Results(
            artists: filtered(artists) { [$0.name] }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            albums: albums.filter { album in
                matches([album.name] + album.artistNames) || (genre.map { album.genres.contains($0) } ?? false)
            },
            tracks: tracks.filter { track in
                matches([track.name] + track.artistNames) || track.genre == genre
            },
            playlists: filtered(playlists) { [$0.name, $0.playlistDescription] }.byLastPlayed
        )
    }

    var body: some View {
        let results = search()

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                masthead(results)
                    .padding(.top, 4)

                if query.isEmpty {
                    if tracks.isEmpty {
                        LibraryEmptyState(text: "Import music to search it")
                    } else {
                        genreIndex
                    }
                } else if results.isEmpty {
                    LibraryEmptyState(text: "Try an artist, a record, a track or a genre")
                } else {
                    resultsList(results)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // `containerBackground`, а не `background`: у экрана в навигации своя
        // непрозрачная подложка. Светится то, что играет, — как в библиотеке.
        .containerBackground(for: .navigation) {
            CoverAura(palette: audioPlayer.currentTrack == nil ? nil : audioPlayer.palette, breathes: false)
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Artists, records, tracks, genres")
    }

    // MARK: - Шапка

    private func masthead(_ results: Results) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 44, weight: .heavy).width(.compressed))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .contentTransition(.opacity)

            Text(passport(results))
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    /// Жанр пишется как есть, а слово — в кавычках: так видно, что это то,
    /// что ты набрал, а не название раздела.
    private var title: String {
        if query.isEmpty { return "Search" }
        if let genre { return genre.rawValue }
        return "“\(query)”"
    }

    /// Без запроса — что вообще есть в фонотеке; с запросом — сколько нашлось.
    private func passport(_ results: Results) -> String {
        let parts: [String?]

        if query.isEmpty {
            parts = [
                ArtistDiscography.count(tracks.count, "TRACK", "TRACKS"),
                ArtistDiscography.count(albums.count, "RECORD", "RECORDS"),
                ArtistDiscography.count(artists.count, "ARTIST", "ARTISTS"),
            ]
        } else {
            parts = [
                genre == nil ? nil : "GENRE",
                ArtistDiscography.count(results.artists.count, "ARTIST", "ARTISTS"),
                ArtistDiscography.count(results.albums.count, "RECORD", "RECORDS"),
                ArtistDiscography.count(results.tracks.count, "TRACK", "TRACKS"),
                ArtistDiscography.count(results.playlists.count, "PLAYLIST", "PLAYLISTS"),
            ]
        }

        let passport = parts.compactMap { $0 }.joined(separator: "  ·  ")
        return passport.isEmpty ? "NOTHING FOUND" : passport
    }

    // MARK: - Жанры

    private struct GenreCount: Identifiable {
        let genre: Genre
        let count: Int

        var id: Genre { genre }
    }

    /// Жанры фонотеки, от самого большого: слово и сколько в нём треков.
    /// Нажатие ищет по жанру — запрос, совпавший с жанром, ищет и жанр тоже.
    private var genreIndex: some View {
        let counts = Dictionary(grouping: tracks, by: \.genre)
            .map { GenreCount(genre: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.genre.rawValue < $1.genre.rawValue }

        return VStack(alignment: .leading, spacing: 14) {
            CrateDivider(title: "GENRES", detail: "\(counts.count)")

            FlowLayout(spacing: 16) {
                ForEach(counts) { entry in
                    Button {
                        searchText = entry.genre.rawValue
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(entry.genre.rawValue)
                                .font(.system(size: 26, weight: .heavy).width(.compressed))
                                .foregroundStyle(.primary)

                            Text("\(entry.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.genre.rawValue), \(entry.count) tracks")
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Результаты

    @ViewBuilder
    private func resultsList(_ results: Results) -> some View {
        if !results.artists.isEmpty {
            shelf("ARTISTS", count: results.artists.count) {
                VStack(spacing: 14) {
                    ForEach(results.artists) { artist in
                        ArtistsTabArtistCell(artist: artist)
                    }
                }
                .padding(.horizontal)
            }
        }

        if !results.albums.isEmpty {
            shelf("RECORDS", count: results.albums.count) {
                LazyVGrid(columns: albumColumns, spacing: 24) {
                    ForEach(results.albums) { album in
                        AlbumCell(album: album)
                    }
                }
                .padding(.horizontal)
            }
        }

        if !results.tracks.isEmpty {
            shelf("TRACKS", count: results.tracks.count) {
                ForEach(results.tracks) { track in
                    TrackCell(track: track, queue: results.tracks, leadingStyle: .artwork)
                }
            }
        }

        if !results.playlists.isEmpty {
            shelf("PLAYLISTS", count: results.playlists.count) {
                VStack(spacing: 10) {
                    ForEach(results.playlists) { playlist in
                        PlaylistLink(playlist: playlist)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// Раздел за разделителем ящика. Строки треков сами держат отступы,
    /// остальное — в рамке экрана.
    private func shelf<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CrateDivider(title: title, detail: "\(count)")
                .padding(.horizontal)
            content()
        }
    }

    // MARK: - Совпадения

    /// Совпадение — если хоть одно из полей содержит запрос, без учёта регистра.
    private func matches(_ fields: [String]) -> Bool {
        fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func filtered<T>(_ items: [T], fields: (T) -> [String]) -> [T] {
        items.filter { matches(fields($0)) }
    }
}
