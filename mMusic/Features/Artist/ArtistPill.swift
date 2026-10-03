import SwiftUI

/// Кликабельная капсула артиста — та же форма, что в редакторе трека,
/// но вместо правки она ведёт на страницу артиста.
struct ArtistPill: View {

    let artist: Artist

    var body: some View {
        NavigationLink {
            ArtistView(artist: artist)
        } label: {
            HStack(spacing: 4) {
                // С фотографией капсула становится узнаваемой с одного взгляда,
                // без неё остаётся прежний значок.
                if artist.artwork == nil {
                    Image(systemName: "person.fill")
                } else {
                    ArtistAvatar(artist: artist, size: 18)
                        .padding(.leading, -4)
                }

                Text(artist.name)
            }
            // Фон от .primary, а не белый: у плеера схема переворачивается под
            // обложку, и фиксированный цвет на светлой обложке пропал бы.
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.15), in: Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

/// Все артисты работы разом, с переносом на следующую строку.
struct ArtistPillRow: View {

    let artists: [Artist]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(artists) { artist in
                ArtistPill(artist: artist)
            }
        }
    }
}
