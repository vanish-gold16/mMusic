import SwiftData
import SwiftUI

/// Шапка библиотеки: разделы — не системный переключатель, а указатель
/// из крупных сжатых слов, как разделы на обложке журнала. Открытый раздел
/// напечатан в полную силу, остальные — бледно; нажатие на слово открывает
/// раздел. Под указателем паспорт раздела, а у альбомов в нём же — порядок:
/// «BY DATE ADDED ⌄».
///
/// Слова «Library» здесь нет: оно уже написано на вкладке.
struct LibraryMasthead: View {

    @Binding var section: LibrarySection
    @Binding var albumSort: AlbumSort

    @Query private var albums: [Album]
    @Query private var playlists: [Playlist]
    @Query private var artists: [Artist]
    @Query private var tracks: [Track]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Самый крупный кегль, при котором все четыре слова встают в строку.
            ViewThatFits(in: .horizontal) {
                index(size: 34)
                index(size: 30)
                index(size: 26)
                index(size: 22)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(passport)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)

                if section == .albums {
                    sortMenu
                }

                Spacer(minLength: 0)
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .animation(.snappy(duration: 0.25), value: section)
    }

    private func index(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.4) {
            ForEach(LibrarySection.allCases) { option in
                let isOpen = option == section

                Button {
                    section = option
                } label: {
                    Text(option.title)
                        .font(.system(size: size, weight: .heavy).width(.compressed))
                        .foregroundStyle(isOpen ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOpen ? .isSelected : [])
            }
        }
        // Идеальная ширина, а не сжатая: по ней `ViewThatFits` и выбирает кегль.
        .fixedSize()
    }

    /// Порядок альбомов словами. Акцентом — чтобы было видно, что это кнопка.
    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $albumSort) {
                ForEach(AlbumSort.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("BY \(albumSort.rawValue.uppercased())")
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.tint)
            .lineLimit(1)
        }
        .accessibilityLabel("Sort albums by \(albumSort.rawValue)")
    }

    /// Что в открытом разделе. Пустые части не пишутся.
    private var passport: String {
        switch section {
        case .albums:
            let minutes = Int((tracks.reduce(0) { $0 + $1.duration } / 60).rounded())
            return [
                ArtistDiscography.count(albums.count, "RECORD", "RECORDS"),
                minutes >= 60 ? "\(minutes / 60) H" : (minutes > 0 ? "\(minutes) MIN" : nil),
            ]
            .compactMap { $0 }
            .joined(separator: "  ·  ")

        case .playlists:
            let pinned = playlists.filter(\.isPinned).count
            return [
                ArtistDiscography.count(playlists.count, "PLAYLIST", "PLAYLISTS"),
                pinned > 0 ? "\(pinned) PINNED" : nil,
            ]
            .compactMap { $0 }
            .joined(separator: "  ·  ")

        case .artists:
            // Те, у кого своих пластинок нет, а гостевые есть, — их в списке
            // узнают по «FEATURED ON», и сколько их, видно сразу.
            let guests = artists.filter { artist in
                let discography = ArtistDiscography(artist: artist)
                return discography.albums.isEmpty && discography.singles.isEmpty && !discography.featuredOn.isEmpty
            }.count
            return [
                ArtistDiscography.count(artists.count, "ARTIST", "ARTISTS"),
                guests > 0 ? "\(guests) ONLY AS GUESTS" : nil,
            ]
            .compactMap { $0 }
            .joined(separator: "  ·  ")

        case .smart:
            return "COLLECTED BY RULES  ·  CHANGE AS YOU LISTEN"
        }
    }
}
