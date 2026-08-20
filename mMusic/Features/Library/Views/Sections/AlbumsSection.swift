import SwiftData
import SwiftUI

/// Сетка альбомов. Своего поиска больше не держит — для этого есть вкладка Search,
/// которая ищет сразу по всему.
struct AlbumsSection: View {

    let sort: AlbumSort

    @Query private var albums: [Album]

    private let columns = [GridItem(.flexible(), alignment: .top),
                           GridItem(.flexible(), alignment: .top)]

    private var sorted: [Album] {
        switch sort {
        case .dateAdded:
            albums.sorted { $0.addedAt > $1.addedAt }
        case .name:
            albums.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .release:
            albums.sorted { ($0.release ?? .distantPast) > ($1.release ?? .distantPast) }
        }
    }

    var body: some View {
        if albums.isEmpty {
            LibraryEmptyState(text: "No albums yet")
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sorted) { album in
                    AlbumCell(album: album)
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Пустой раздел: короткая строка вместо системной картинки с заголовком —
/// внутри экрана, у которого уже есть заголовок, та выглядит громко.
struct LibraryEmptyState: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
    }
}
