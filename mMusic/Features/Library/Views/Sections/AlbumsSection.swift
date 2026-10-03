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

    /// Соседние альбомы с одинаковой меткой — в один ящик. Идём по уже
    /// отсортированному списку, поэтому порядок внутри ящиков тот же.
    private var crates: [AlbumCrate] {
        var crates: [AlbumCrate] = []

        for album in sorted {
            let key = crateKey(for: album)
            if crates.last?.lastKey == key {
                crates[crates.count - 1].albums.append(album)
            } else {
                crates.append(AlbumCrate(firstKey: key, lastKey: key, albums: [album]))
            }
        }

        return sort == .name ? Self.mergingSparse(crates) : crates
    }

    /// Альбомов на букву обычно один-два, и ящик на каждую букву был бы
    /// полупустой строкой. Соседние буквы сливаются, пока в ящике не наберётся
    /// две полные строки, — как «B–D» на разделителе в музыкальном магазине.
    /// «#» ни с кем не сливается: «#–A» не читается.
    private static func mergingSparse(_ crates: [AlbumCrate]) -> [AlbumCrate] {
        let minimum = 4
        var merged: [AlbumCrate] = []

        for crate in crates {
            if let last = merged.last, last.albums.count < minimum,
               last.firstKey != "#", crate.firstKey != "#" {
                merged[merged.count - 1].albums += crate.albums
                merged[merged.count - 1].lastKey = crate.lastKey
            } else {
                merged.append(crate)
            }
        }

        // Хвост алфавита, которому не хватило соседей, — к предыдущему ящику:
        // одинокая «Z» в конце была бы той же полупустой строкой.
        if merged.count > 1, let tail = merged.last, tail.albums.count < minimum,
           tail.firstKey != "#", merged[merged.count - 2].firstKey != "#" {
            merged.removeLast()
            merged[merged.count - 1].albums += tail.albums
            merged[merged.count - 1].lastKey = tail.lastKey
        }

        return merged
    }

    var body: some View {
        if albums.isEmpty {
            LibraryEmptyState(text: "No albums yet")
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(crates) { crate in
                    Section {
                        ForEach(crate.albums) { album in
                            AlbumCell(album: album)
                        }
                    } header: {
                        CrateDivider(title: crate.title, detail: "\(crate.albums.count)")
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
            // Цифры, знаки и эмодзи — под одним «#», как в конце алфавитного указателя.
            guard let first = album.name.trimmingCharacters(in: .whitespaces).first, first.isLetter else {
                return "#"
            }
            return String(first).uppercased()
        }
    }
}

/// Один ящик: метка разделителя и альбомы за ним. Метка — диапазон
/// от первого ключа до последнего, если в ящик слились соседние буквы.
private struct AlbumCrate: Identifiable {
    let firstKey: String
    var lastKey: String
    var albums: [Album]

    var title: String {
        firstKey == lastKey ? firstKey : "\(firstKey)–\(lastKey)"
    }

    /// По первому альбому: метка может повториться — «#» бывает и в начале,
    /// и в конце алфавита, если имя начинается с эмодзи.
    var id: PersistentIdentifier { albums[0].persistentModelID }
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
