import SwiftData
import SwiftUI

/// Куда ляжет трек: лента обложек вместо выпадающего списка названий.
/// Первым — пунктирный «новый сингл», как пустой слот в плейлисте, дальше
/// альбомы библиотеки, свежие слева: трек обычно докладывают в то, что
/// добавляли недавно.
///
/// Выбранный альбом лента сама прокручивает в кадр — в том числе когда его
/// выбрала не рука, а тег файла.
struct AlbumDestinationStrip: View {

    let albums: [Album]
    @Binding var selection: Album?

    private let side: CGFloat = 76

    /// У «нового сингла» и альбомов разные идентификаторы, а прокрутке нужен один тип.
    private enum ItemID: Hashable {
        case single
        case album(PersistentIdentifier)
    }

    private var selectedID: ItemID {
        selection.map { .album($0.persistentModelID) } ?? .single
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    newSingle
                        .id(ItemID.single)

                    ForEach(albums) { album in
                        Button {
                            selection = album
                        } label: {
                            AlbumDestinationChip(
                                album: album,
                                side: side,
                                isSelected: selection?.persistentModelID == album.persistentModelID
                            )
                        }
                        .buttonStyle(.plain)
                        .id(ItemID.album(album.persistentModelID))
                    }
                }
                .padding(.horizontal)
                // Место под обводку и галочку выбранной карточки: иначе их срезал бы край ленты.
                .padding(.vertical, 10)
            }
            .onChange(of: selectedID) { _, id in
                withAnimation(.snappy) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var newSingle: some View {
        let isSelected = selection == nil
        let shape = RoundedRectangle(cornerRadius: side * 0.09, style: .continuous)

        return Button {
            selection = nil
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                shape
                    .strokeBorder(
                        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.5)),
                        style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, dash: isSelected ? [] : [5, 5])
                    )
                    .frame(width: side, height: side)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }

                AlbumDestinationCaption(title: "New single", detail: "SINGLE", side: side)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Карточка альбома в ленте: обложка и подпись. Обложка уменьшается в фоне —
/// альбомов в ленте может быть сотня, и декодировать их целиком незачем.
private struct AlbumDestinationChip: View {

    let album: Album
    let side: CGFloat
    let isSelected: Bool

    @State private var cover: UIImage?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.09, style: .continuous)

        VStack(alignment: .leading, spacing: 6) {
            shape
                .fill(.quaternary)
                .frame(width: side, height: side)
                .overlay {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(shape)
                // Обводка снаружи обложки, а не поверх: обложку она не съедает.
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: side * 0.09 + 4, style: .continuous)
                            .strokeBorder(.tint, lineWidth: 2.5)
                            .padding(-4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .tint)
                            .offset(x: 6, y: -6)
                    }
                }

            AlbumDestinationCaption(title: album.name, detail: album.formatLabel, side: side)
        }
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: album.artwork?.count) {
            let data = album.artwork
            cover = await Task.detached(priority: .utility) {
                data.flatMap { UIImage.thumbnail(from: $0, side: 230) }
            }.value
        }
    }
}

/// Подпись под карточкой: имя в одну строку и формат мелко, как на корешке.
private struct AlbumDestinationCaption: View {

    let title: String
    let detail: String
    let side: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(detail.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .frame(width: side, alignment: .leading)
    }
}
