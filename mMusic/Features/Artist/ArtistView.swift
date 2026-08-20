import SwiftData
import SwiftUI

struct ArtistView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    var artist: Artist

    @State private var sortOption: SortOption = .mostPlayed

    private enum SortOption: String, CaseIterable, Identifiable {
        case mostPlayed = "Most played"
        case albumOrder = "Album order"
        case name = "Name"
        case recent = "Recently played"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .albumOrder: "square.stack"
            case .mostPlayed: "play.circle"
            case .name: "textformat"
            case .recent: "clock"
            }
        }
    }

    private let columns = [GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top)]

    /// Альбомы, где артист указан в авторах.
    private var albums: [Album] {
        var seen = Set<PersistentIdentifier>()
        return artist.credits
            .compactMap(\.album)
            .filter { seen.insert($0.persistentModelID).inserted }
            .sorted { ($0.release ?? .distantPast) > ($1.release ?? .distantPast) }
    }

    /// Треки альбомов артиста плюс те, где он отмечен лично (обычно `.featured`).
    /// Авторство наследуется от альбома, поэтому одних прямых credits мало.
    private var allTracks: [Track] {
        let fromAlbums = albums.flatMap { $0.tracks.sorted { $0.position < $1.position } }
        let own = artist.credits.compactMap(\.track)

        var seen = Set<PersistentIdentifier>()
        return (fromAlbums + own).filter { seen.insert($0.persistentModelID).inserted }
    }

    /// Порядок по альбомам — исходный, его и оставляем как есть.
    private var tracks: [Track] {
        switch sortOption {
        case .mostPlayed:
            // При равном счёте порядок альбома — иначе непрослушанные встают как попало.
            allTracks.enumerated()
                .sorted { ($0.element.playCount, $1.offset) > ($1.element.playCount, $0.offset) }
                .map(\.element)
        case .albumOrder:
            allTracks
        case .name:
            allTracks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            allTracks.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        }
    }

    private var totalPlays: Int {
        allTracks.reduce(0) { $0 + $1.playCount }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header

                if !tracks.isEmpty {
                    playButtons
                }

                if !albums.isEmpty {
                    section("Albums") {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(albums) { album in
                                AlbumCell(album: album)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if !tracks.isEmpty {
                    section("Tracks", trailing: sortMenu) {
                        ForEach(tracks) { track in
                            TrackCell(track: track, queue: tracks, leadingStyle: .artwork, showPlayCount: true)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No tracks",
                        systemImage: "music.note",
                        description: Text("Nothing in the library credits this artist yet.")
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.mic")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundStyle(.secondary)
                .frame(width: 120, height: 120)
                .background(Color.gray.opacity(0.2), in: Circle())

            Text(artist.name)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summary: String {
        var parts = ["\(albums.count) albums", "\(allTracks.count) tracks"]
        if totalPlays > 0 { parts.append("\(totalPlays) plays") }

        return parts.joined(separator: " • ")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var playButtons: some View {
        HStack {
            Button {
                audioPlayer.play(tracks)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.glassProminent)

            Button {
                audioPlayer.playShuffled(tracks)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
        }
        .tint(.orange)
        .padding(.horizontal)
    }

    private func section<Content: View, Trailing: View>(
        _ title: String,
        trailing: Trailing = EmptyView(),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title2)
                    .bold()
                Spacer()
                trailing
            }
            .padding(.horizontal)

            content()
        }
    }
}
