import SwiftData
import SwiftUI

struct HomeView: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext

    /// Только те, что уже играли: у остальных `lastPlayedAt` пуст и в ленте им не место.
    @Query(
        filter: #Predicate<Track> { $0.lastPlayedAt != nil },
        sort: \Track.lastPlayedAt,
        order: .reverse
    ) private var playedTracks: [Track]

    @Query private var allTracks: [Track]

    @State private var showSettings = false
    /// Микс живёт в состоянии, а не пересчитывается в `body`: иначе он перетасовывался бы
    /// на каждую перерисовку и кнопка «play» запускала бы не то, что показано.
    @State private var mix: [Track] = []

    private var recentTracks: [Track] {
        Array(playedTracks.prefix(15))
    }

    var body: some View {
        Group {
            if allTracks.isEmpty {
                ContentUnavailableView(
                    "Library is empty",
                    systemImage: "music.note",
                    description: Text("Import music from the Library tab.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task(id: allTracks.count) {
            // Пересобираем и когда микса ещё нет, и когда библиотека изменилась:
            // иначе предложение остаётся вчерашним, а удалённый трек висит в нём ссылкой.
            refreshMix()
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !recentTracks.isEmpty {
                    recentlyPlayed
                }
                randomMix
            }
            .padding(.vertical)
        }
    }

    private var recentlyPlayed: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Recently played")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(recentTracks.enumerated()), id: \.element.id) { index, track in
                        RecentTrackCard(track: track)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                audioPlayer.play(recentTracks, startingAt: index)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var randomMix: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                SectionLabel("Random mix")

                Spacer()

                Button {
                    saveMixAsPlaylist()
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                Button {
                    refreshMix()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .font(.subheadline)
            .padding(.horizontal)

            Button {
                audioPlayer.play(mix)
            } label: {
                HStack(spacing: 12) {
                    mixArtwork

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(mix.count) tracks")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(mix.prefix(3).map(\.name).joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .padding(12)
                .contentShape(Rectangle())
                .glassEffect()
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .contextMenu {
                Button {
                    audioPlayer.playShuffled(mix)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                }
                Button {
                    saveMixAsPlaylist()
                } label: {
                    Label("Save as playlist", systemImage: "text.badge.plus")
                }
                Button {
                    refreshMix()
                } label: {
                    Label("Shuffle again", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    /// Четыре обложки плиткой — микс не принадлежит ни одному альбому,
    /// поэтому своей картинки у него нет.
    private var mixArtwork: some View {
        let artworks = mix.prefix(4).map(\.displayArtwork)

        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(35), spacing: 0), count: 2), spacing: 0) {
            ForEach(Array(artworks.enumerated()), id: \.offset) { _, data in
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 35, height: 35)
                    .overlay {
                        if let data, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipped()
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func refreshMix() {
        mix = Array(allTracks.shuffled().prefix(25))
    }

    /// Микс живёт до следующего обновления — эта кнопка превращает удачный набор в плейлист.
    private func saveMixAsPlaylist() {
        guard !mix.isEmpty else { return }

        let playlist = Playlist(name: "Mix \(Date.now.formatted(date: .abbreviated, time: .shortened))", items: [])
        modelContext.insert(playlist)

        for (position, track) in mix.enumerated() {
            modelContext.insert(TrackPlaylistItem(track: track, playlist: playlist, position: position))
        }
    }
}
