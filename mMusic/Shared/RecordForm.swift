import SwiftUI

// Детали форм, в которых собирают пластинку: новый трек, новый альбом, трек
// внутри нового альбома. Формы не таблицы полей, а страница будущей пластинки —
// поэтому и детали те же, что на страницах альбома и плейлиста: крупное сжатое
// имя, разделы под метками-разделителями, стекло и пунктир там, где пусто.

/// Раздел формы: метка-разделитель, как сторона пластинки на странице альбома,
/// и под ней содержимое.
struct RecordFormSection<Content: View, Trailing: View>: View {

    let title: String
    var detail: String = ""
    var trailing: Trailing
    @ViewBuilder var content: Content

    init(
        _ title: String,
        detail: String = "",
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                CrateDivider(title: title.uppercased(), detail: detail.uppercased(), size: 22)
                trailing
            }
            .padding(.horizontal)

            content
        }
    }
}

/// Имя прямо в шапке, тем же шрифтом, каким оно будет стоять на странице
/// альбома: что видишь, то и получишь.
struct RecordTitleField: View {

    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 40

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.system(size: size, weight: .heavy).width(.compressed))
            .lineLimit(1...3)
            .focused($isFocused)
            .submitLabel(.done)
            .onChange(of: text) { _, newValue in
                // В многострочном поле Return вставляет перенос — а имени он
                // не нужен: Return здесь значит «готово».
                guard newValue.contains("\n") else { return }
                text = newValue.replacingOccurrences(of: "\n", with: "")
                isFocused = false
            }
    }
}

/// Паспорт под именем мелкими разреженными буквами: «LP  ·  12 TRACKS  ·  43 MIN».
struct RecordPassport: View {

    let parts: [String]

    var body: some View {
        Text(parts.joined(separator: "  ·  ").uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

/// Мелкая подсказка под полем — тем же шрифтом, что паспорт, только тише.
struct RecordHint: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(.tertiary)
    }
}

/// Жанр — крупным словом в стеклянной капсуле, а не строкой таблицы.
/// Вариантов шесть десятков, поэтому выбор — системным меню, где их видно столбцом.
struct GenreMenu: View {

    @Binding var genre: Genre

    var body: some View {
        Menu {
            Picker("Genre", selection: $genre) {
                ForEach(Genre.allCases, id: \.self) { genre in
                    Text(genre.rawValue).tag(genre)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(genre.rawValue)
                    .font(.system(size: 26, weight: .heavy).width(.compressed))
                    .foregroundStyle(Color.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .glassEffect()
        }
        .buttonStyle(.plain)
    }
}

/// Дата выхода. Её может и не быть — тогда на её месте пустой пунктирный слот,
/// как у всех «сюда можно что-то положить».
struct ReleaseDateField: View {

    @Binding var date: Date?

    var body: some View {
        if let current = date {
            HStack(spacing: 8) {
                DatePicker(
                    "Release date",
                    selection: Binding(get: { current }, set: { date = $0 }),
                    displayedComponents: .date
                )
                .labelsHidden()

                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove release date")
            }
        } else {
            DashedSlot(title: "Add release date", systemImage: "calendar", cornerRadius: 26) {
                date = .now
            }
            .frame(maxWidth: 220)
        }
    }
}

/// Обложка, которую меняют нажатием: меню «выбрать / убрать» и значок камеры
/// в углу, чтобы было видно, что по ней можно нажать.
struct CoverEditMenu<Label: View>: View {

    @Binding var artworkData: Data?
    @ViewBuilder var label: Label

    @State private var showPicker = false

    var body: some View {
        Menu {
            Button {
                showPicker = true
            } label: {
                SwiftUI.Label(artworkData == nil ? "Add cover" : "Change cover", systemImage: "photo")
            }

            if artworkData != nil {
                Button(role: .destructive) {
                    artworkData = nil
                } label: {
                    SwiftUI.Label("Remove cover", systemImage: "trash")
                }
            }
        } label: {
            label
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: "camera.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(9)
                        .background(.thinMaterial, in: Circle())
                        .padding(10)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cover")
        .sheet(isPresented: $showPicker) {
            ImagePicker(imageData: $artworkData)
        }
    }
}

extension UIImage {

    /// Обложка формы и её цвета — одним заходом в фоне: картинка из тегов
    /// бывает в несколько мегабайт.
    static func coverAndPalette(from data: Data?, side: CGFloat = 600) async -> (UIImage?, CoverPalette?) {
        await Task.detached(priority: .utility) {
            let image = data.flatMap { UIImage.thumbnail(from: $0, side: side) }
            return (image, image?.coverPalette)
        }.value
    }
}
