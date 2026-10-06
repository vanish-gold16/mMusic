import SwiftUI

/// Шапка листов выбора музыки — для плейлиста и для альбома: «Add music»
/// крупным сжатым шрифтом, паспорт «куда и сколько», а под ним вкладки словами,
/// как разделы библиотеки: открытая напечатана в полную силу, другая — бледно.
/// Справа от вкладок — место для своего переключателя листа.
struct TrackPickerMasthead<Extra: View>: View {

    let passport: String
    @Binding var tab: TrackPickerTab
    @ViewBuilder var extra: Extra

    init(passport: String, tab: Binding<TrackPickerTab>, @ViewBuilder extra: () -> Extra = { EmptyView() }) {
        self.passport = passport
        self._tab = tab
        self.extra = extra()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add music")
                .font(.system(size: 34, weight: .heavy).width(.compressed))

            Text(passport)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 14) {
                ForEach(TrackPickerTab.allCases) { option in
                    let isOpen = option == tab

                    Button {
                        withAnimation(.snappy(duration: 0.2)) { tab = option }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 22, weight: .heavy).width(.compressed))
                            .foregroundStyle(isOpen ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOpen ? .isSelected : [])
                }

                Spacer(minLength: 0)

                extra
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

/// Обложка трека в строке выбора. Декодируется в `.task` уменьшенной:
/// в листе выбора сотни строк, и полноразмерная картинка в `body` каждой
/// из них заметно тормозила прокрутку.
struct PickCover: View {

    let track: Track
    var side: CGFloat = 40

    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(.quaternary)
            .frame(width: side, height: side)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .task(id: track.displayArtwork?.count) {
                guard let data = track.displayArtwork else {
                    image = nil
                    return
                }
                let pixels = side * 3
                let thumbnail = await Task.detached(priority: .utility) {
                    UIImage.thumbnail(from: data, side: pixels)
                }.value
                guard !Task.isCancelled else { return }
                image = thumbnail
            }
            .accessibilityHidden(true)
    }
}
