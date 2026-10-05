import SwiftData
import SwiftUI

/// Артисты по алфавиту, разложенные по разделителям, как в ящике магазина:
/// буква — или диапазон «B–D», если на соседние буквы артистов немного.
struct ArtistsSection: View {

    @Query private var artists: [Artist]

    /// Сортировка в Swift, как у альбомов: без учёта регистра и по правилам
    /// языка. Иначе строчная «abba» могла бы отбиться от «ABBA» и разорвать
    /// ящик «A» надвое.
    private var crates: [Crate<Artist>] {
        let sorted = artists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Crate.mergingSparse(Crate.grouping(sorted, by: \.name.crateLetter), minimum: 3)
    }

    var body: some View {
        if artists.isEmpty {
            LibraryEmptyState(text: "No artists yet")
        } else {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(crates) { crate in
                    Section {
                        ForEach(crate.items) { artist in
                            ArtistsTabArtistCell(artist: artist)
                        }
                    } header: {
                        CrateDivider(title: crate.title, detail: "\(crate.items.count)")
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
