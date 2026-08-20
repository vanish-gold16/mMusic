import SwiftData
import SwiftUI

/// Список автоподборок. Пустые не показываются — карточка «0 треков» только мешает.
struct SmartPlaylistsSection: View {

    @Query private var tracks: [Track]

    private var available: [(playlist: SmartPlaylist, count: Int)] {
        SmartPlaylist.allCases
            .map { ($0, $0.tracks(from: tracks).count) }
            .filter { $0.1 > 0 }
    }

    var body: some View {
        if available.isEmpty {
            LibraryEmptyState(text: "Nothing to collect yet")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(available, id: \.playlist.id) { entry in
                    NavigationLink {
                        SmartPlaylistView(playlist: entry.playlist)
                    } label: {
                        row(entry.playlist, count: entry.count)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func row(_ playlist: SmartPlaylist, count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: playlist.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(playlist.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
        .contentShape(Rectangle())
        .glassEffect()
    }
}
