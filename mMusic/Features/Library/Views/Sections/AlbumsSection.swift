import SwiftData
import SwiftUI

/// Альбомы как ящик с пластинками: сетка конвертов, разложенная по
/// разделителям. Что написано на разделителе, решает сортировка — месяц,
/// когда добавлен, десятилетие выхода или буквы имени.
///
/// Своего поиска не держит — для этого есть вкладка Search, которая ищет
/// сразу по всему.
struct AlbumsSection: View {

    let sort: AlbumSort

    @Query private var albums: [Album]

    private let columns = [GridItem(.flexible(), spacing: 16, alignment: .top),
                           GridItem(.flexible(), spacing: 16, alignment: .top)]

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

    /// Альбомы по ящикам. Что написано на разделителе, решает сортировка.
    /// Буквы сливаются, пока в ящике не наберётся две полные строки сетки.
    private var crates: [Crate<Album>] {
        let crates = Crate.grouping(sorted, by: crateKey(for:))
        return sort == .name ? Crate.mergingSparse(crates, minimum: 4) : crates
    }

    var body: some View {
        if albums.isEmpty {
            LibraryEmptyState(text: "No albums yet")
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(crates) { crate in
                    Section {
                        ForEach(crate.items) { album in
                            AlbumCell(album: album)
                        }
                    } header: {
                        CrateDivider(title: crate.title, detail: "\(crate.items.count)")
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func crateKey(for album: Album) -> String {
        switch sort {
        case .dateAdded:
            // Год — только у прошлых лет: у текущего он ничего не добавляет.
            let isThisYear = Calendar.current.isDate(album.addedAt, equalTo: .now, toGranularity: .year)
            let style = isThisYear ? Date.FormatStyle().month(.wide) : Date.FormatStyle().month(.wide).year()
            return album.addedAt.formatted(style.locale(.interface)).uppercased()

        case .release:
            // Десятилетия, а не годы: альбом на год — снова полупустые строки.
            // Точный год есть в паспорте под каждым конвертом.
            guard let release = album.release else { return "NO DATE" }
            let year = Calendar.current.component(.year, from: release)
            return "\(year / 10 * 10)s"

        case .name:
            return album.name.crateLetter
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
