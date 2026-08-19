import SwiftData
import SwiftUI

struct ArtistView: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    var artist: Artist

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
    private var tracks: [Track] {
        let fromAlbums = albums.flatMap { $0.tracks.sorted { $0.position < $1.position } }
        let own = artist.credits.compactMap(\.track)

        var seen = Set<PersistentIdentifier>()
        return (fromAlbums + own).filter { seen.insert($0.persistentModelID).inserted }
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
                    section("Tracks") {
                        ForEach(tracks) { track in
                            TrackCell(track: track, queue: tracks, leadingStyle: .artwork)
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

            Text("\(albums.count) albums • \(tracks.count) tracks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal)
            content()
        }
    }
}
