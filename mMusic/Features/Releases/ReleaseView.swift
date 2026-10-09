import SwiftData
import SwiftUI

/// Карточка релиза: запечатанная пластинка крупно, кто и когда, треклист
/// из каталога и куда пойти слушать. Сюда ведёт полка на главной, строка
/// входящих и нажатие на уведомление об одном релизе.
struct ReleaseView: View {

    @Environment(ReleaseRadar.self) private var radar
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let id: String

    @State private var tracks: [ReleaseTrack] = []
    @State private var isLoadingTracks = true
    @State private var palette: CoverPalette?
    /// Те из библиотеки, кто на релизе, — капсулами, ведущими на их страницы.
    @State private var artists: [Artist] = []

    var body: some View {
        Group {
            if let release = radar.release(id: id) {
                content(release)
            } else {
                // Радар держит релизы несколько месяцев — уведомление могло пережить свой релиз.
                ContentUnavailableView(
                    "This drop is gone",
                    systemImage: "opticaldisc",
                    description: Text("The radar only keeps releases from the last few months.")
                )
            }
        }
        .containerBackground(for: .navigation) {
            CoverAura(palette: palette, breathes: false)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: id) {
            await load()
        }
    }

    private func content(_ release: RadarRelease) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ReleaseSleeve(release: release, accent: palette?.accent ?? audioPlayer.accent, pixels: 900)
                    .frame(maxWidth: 300)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(release.displayTitle)
                        .font(.system(size: 44, weight: .heavy).width(.compressed))
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)

                    Text(ReleaseCaption.who(release))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(passport(release))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)

                links(release)
                    .padding(.horizontal)

                if !artists.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("In your library")
                        ArtistPillRow(artists: artists)
                            .padding(.horizontal)
                    }
                }

                tracklist
            }
            .padding(.bottom, 32)
        }
        .tint(palette?.accent ?? audioPlayer.accent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let link = release.link {
                        ShareLink(item: link)
                    }
                    Button(role: .destructive) {
                        radar.dismiss(release.id)
                        dismiss()
                    } label: {
                        Label("Not interested", systemImage: "hand.thumbsdown")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    /// «SINGLE  ·  FRI, OCT 10, 2026  ·  3 TRACKS  ·  DEEZER». У анонса —
    /// «OUT FRI, OCT 10»: он ещё не вышел.
    private func passport(_ release: RadarRelease) -> String {
        var parts = [release.kind.label]

        if let day = RadarLogic.date(of: release.releaseDay) {
            let date = day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year().locale(.interface))
            parts.append(day > .now ? "out \(date)" : date)
        }
        if !tracks.isEmpty {
            parts.append(tracks.count == 1 ? "1 track" : "\(tracks.count) tracks")
        }
        parts.append(release.source.title)

        return parts.joined(separator: "  ·  ").uppercased()
    }

    /// Слушать — там, где релиз нашёлся. Скачать его можно с SoundCloud:
    /// поиск открывается уже с именем и названием.
    private func links(_ release: RadarRelease) -> some View {
        HStack(spacing: 12) {
            if let link = release.link {
                Link(destination: link) {
                    Label(release.source.title, systemImage: "arrow.up.right")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                }
                .buttonStyle(.glassProminent)
            }

            if let search = soundCloudSearch(release) {
                Link(destination: search) {
                    Label("SoundCloud", systemImage: "magnifyingglass")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                }
                .buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder
    private var tracklist: some View {
        if isLoadingTracks {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CrateDivider(title: "TRACKS", detail: "\(tracks.count)")

                ForEach(tracks) { track in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(track.number)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 22, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.title)
                                .lineLimit(2)
                            if !track.guests.isEmpty {
                                Text(track.guests)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if track.duration > 0 {
                            Text(Duration.seconds(track.duration).formatted(.time(pattern: .minuteSecond)))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Загрузка

    private func load() async {
        guard let release = radar.release(id: id) else { return }

        artists = libraryArtists(of: release)

        async let cover = RemoteImages.palette(at: release.cover)
        async let list = ReleaseTrack.load(for: release)

        palette = await cover
        tracks = await list
        isLoadingTracks = false
    }

    /// Имена в радаре — ключи сравнения, а в базе артист мог остаться
    /// с разобранной «ё» или в другом регистре, поэтому ищем по ключу.
    private func libraryArtists(of release: RadarRelease) -> [Artist] {
        let keys = Set(release.libraryArtists.map(RadarText.key))
        let all = (try? modelContext.fetch(FetchDescriptor<Artist>(sortBy: [SortDescriptor(\.name)]))) ?? []

        var seen = Set<String>()
        return all.filter { artist in
            let key = RadarText.key(artist.name)
            return !artist.credits.isEmpty && keys.contains(key) && seen.insert(key).inserted
        }
    }

    private func soundCloudSearch(_ release: RadarRelease) -> URL? {
        var components = URLComponents(string: "https://soundcloud.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "\(release.byline) \(release.displayTitle)")]
        return components?.url
    }
}

/// Трек релиза из каталога — только для показа.
private struct ReleaseTrack: Identifiable {
    let id: Int
    let number: Int
    let title: String
    /// Кто на треке, если не тот, кем подписан релиз.
    let guests: String
    /// В секундах. 0 — каталог не сказал.
    let duration: Int

    static func load(for release: RadarRelease) async -> [ReleaseTrack] {
        switch release.source {
        case .deezer:
            guard let album = try? await DeezerClient.album(release.sourceID) else { return [] }
            return (album.tracks?.data ?? []).enumerated().map { index, track in
                let artist = track.artist?.name ?? ""
                return ReleaseTrack(
                    id: track.id,
                    number: index + 1,
                    title: track.title,
                    guests: RadarText.key(artist) == RadarText.key(release.byline) ? "" : artist,
                    duration: track.duration ?? 0
                )
            }

        case .apple:
            guard let songs = try? await AppleMusicClient.tracks(ofCollection: release.sourceID) else { return [] }
            return songs
                .sorted { ($0.discNumber ?? 1, $0.trackNumber ?? 0) < ($1.discNumber ?? 1, $1.trackNumber ?? 0) }
                .enumerated()
                .map { index, song in
                    let artist = song.artistName ?? ""
                    return ReleaseTrack(
                        id: song.trackId ?? index,
                        number: index + 1,
                        title: song.trackName ?? "",
                        guests: RadarText.key(artist) == RadarText.key(release.byline) ? "" : artist,
                        duration: (song.trackTimeMillis ?? 0) / 1000
                    )
                }
        }
    }
}
