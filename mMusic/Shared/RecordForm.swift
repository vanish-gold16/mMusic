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
            GenreCapsule(title: genre.rawValue)
        }
        .buttonStyle(.plain)
    }
}

/// Жанр альбома — та же капсула, что у трека, только выбор в ней ставит жанр
/// сразу всем трекам. Своего жанра у альбома нет (см. `AlbumGenre`): капсула
/// показывает жанр треков, а когда он у них разный — приглушённое «Mixed»,
/// и в меню тогда ничего не отмечено.
///
/// Разные жанры — чья-то ручная работа, и одним нажатием её потом не вернуть,
/// поэтому поверх них жанр ставится только после вопроса. Один жанр на всех
/// меняется сразу: вернуть прежний можно тем же меню.
struct AlbumGenreMenu: View {

    let genre: AlbumGenre
    /// Поставить жанр всем трекам. Как именно — решает форма: правка альбома
    /// пишет в базу сразу, сборка нового — в черновики.
    let onSet: (Genre) -> Void

    /// Жанр, выбранный поверх разных, — ждёт ответа на вопрос.
    @State private var pending: Genre?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Picker("Genre", selection: selection) {
                    // Метки — опциональные, как и выбор: при разных жанрах
                    // выбор nil, и галочки нет ни у одного пункта.
                    ForEach(Genre.allCases, id: \.self) { genre in
                        Text(genre.rawValue).tag(Optional(genre))
                    }
                }
            } label: {
                GenreCapsule(title: genre.common?.rawValue ?? "Mixed", isMixed: genre.isMixed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Genre of all tracks")
            .accessibilityValue(genre.common?.rawValue ?? "Mixed: \(genreList)")

            if let hint {
                RecordHint(hint)
            }
        }
        .confirmationDialog(
            "Set all \(genre.trackCount) tracks to \(pending?.rawValue ?? "")?",
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending
        ) { chosen in
            Button("Set to \(chosen.rawValue)") {
                onSet(chosen)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("Now they are \(genre.genres.map(\.rawValue).joined(separator: ", ")). Any track can still be changed on its own afterwards.")
        }
    }

    /// Выбор в меню. Тот же жанр, что уже у всех, ничего не пишет; жанр поверх
    /// разных сначала спрашивает.
    private var selection: Binding<Genre?> {
        Binding(
            get: { genre.common },
            set: { chosen in
                guard let chosen, chosen != genre.common else { return }

                if genre.isMixed {
                    pending = chosen
                } else {
                    onSet(chosen)
                }
            }
        )
    }

    private var genreList: String {
        genre.genres.map(\.rawValue).joined(separator: " · ")
    }

    /// Что сделает выбор. У единственного трека пояснять нечего: жанр альбома
    /// и есть его жанр.
    private var hint: String? {
        if genre.isMixed {
            return "Now \(genreList) — pick one for all \(genre.trackCount) tracks"
        }
        guard genre.trackCount > 1 else { return nil }
        return "Sets all \(genre.trackCount) tracks at once — any one can still be changed later"
    }
}

/// Капсула жанра: крупное сжатое слово и стрелки меню. «Mixed» в ней тише
/// настоящего жанра — это не жанр, а то, что жанра одного нет.
private struct GenreCapsule: View {

    let title: String
    var isMixed = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 26, weight: .heavy).width(.compressed))
                .foregroundStyle(isMixed ? Color.secondary : Color.primary)

            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .frame(height: 50)
        .glassEffect()
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

/// Формат тремя капсулами: выбранный залит цветом обложки, и диск в конверте
/// сразу становится своего размера — сингл маленький, LP большой.
struct AlbumTypePicker: View {

    @Binding var type: Album.AlbumType
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Album.AlbumType.allCases, id: \.self) { option in
                let isSelected = option == type

                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                        type = option
                    }
                } label: {
                    Text(option.rawValue.uppercased())
                        .font(.system(size: 18, weight: .heavy).width(.compressed))
                        .tracking(0.8)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(minWidth: 64, minHeight: 38)
                        .glassEffect(isSelected ? .regular.tint(accent) : .regular, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// Три пустых слота — откуда положить музыку в альбом: библиотека, файлы,
/// SoundCloud. Пунктир тот же, что у «Add music» в плейлисте: по всему
/// приложению так выглядит «сюда можно положить».
struct MusicSourceSlots: View {

    /// Подпись над слотами — «Add music to disc 2», когда пластинок несколько.
    var hint: String?
    let onLibrary: () -> Void
    let onFiles: () -> Void
    let onSoundCloud: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let hint {
                RecordHint(hint)
            }

            HStack(spacing: 10) {
                slot("Library", systemImage: "music.note.list", action: onLibrary)
                slot("Files", systemImage: "square.and.arrow.down", action: onFiles)
                slot("SoundCloud", systemImage: "link", action: onSoundCloud)
            }
        }
    }

    private func slot(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        // `.borderless`: в строке списка три кнопки, и без явного стиля нажатие
        // на любую срабатывало бы как нажатие на всю строку — то есть на все три.
        return Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)

                // Цвета явные: `.borderless` красит иерархические `.secondary`
                // в акцент, а пунктир по всему приложению серый.
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background {
                shape.strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            .contentShape(shape)
        }
        .buttonStyle(.borderless)
    }
}

extension View {

    /// Строка списка без системного оформления: ни фона, ни разделителя,
    /// ни отступов — форма рисует всё сама. Список, а не `ScrollView`, там,
    /// где строки переставляют и смахивают.
    func bareRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
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
