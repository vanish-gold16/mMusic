import SwiftUI

/// Правка статического текста трека. Открывается листом и из плеера, и из
/// редактора трека — поэтому свой `NavigationStack` носит с собой.
///
/// Сверху — имя трека крупно, как в остальных формах, и счёт строк: длинный
/// текст видно и без прокрутки до конца.
struct LyricsEditorView: View {

    let track: Track

    @Environment(\.dismiss) private var dismiss

    /// Черновик: SwiftData пишет изменение модели в базу сразу, и правь мы
    /// `track.lyrics` напрямую, кнопке «SCRAP» нечего было бы выбрасывать.
    @State private var draft = ""
    /// Клавиатура поднимается сама, когда текста ещё нет: пустой экран открывают,
    /// чтобы писать, а не чтобы смотреть.
    @FocusState private var isFocused: Bool
    @State private var lookup: LyricsLookupStatus = .idle

    /// «TEXT  ·  24 LINES», у текста с таймкодами — «TEXT  ·  SYNCED  ·  24 LINES».
    /// Пустые строки между куплетами и проигрыши не считаются.
    private var passport: [String] {
        if let synced = Lyrics.synced(draft) {
            let lines = synced.filter { !$0.text.isEmpty }.count
            return ["text", "synced", lines == 1 ? "1 line" : "\(lines) lines"]
        }

        let lines = draft.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        guard lines > 0 else { return ["text", "empty"] }
        return ["text", lines == 1 ? "1 line" : "\(lines) lines"]
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $draft)
                .focused($isFocused)
                .font(.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .overlay(alignment: .topLeading) {
                    // У TextEditor нет placeholder, поэтому подсказка кладётся
                    // сверху и убирается с первым же символом.
                    if draft.isEmpty {
                        Text("Paste or type the text…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 17)
                            .allowsHitTesting(false)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.name)
                            .font(.system(size: 32, weight: .heavy).width(.compressed))
                            .lineLimit(2)
                        HStack(spacing: 12) {
                            RecordPassport(parts: lookup == .idle || lookup == .searching ? passport : [lookup.kicker])
                                .frame(maxWidth: .infinity, alignment: .leading)
                            findButton
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetActionButton(.scrap) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        SheetActionButton(.save) {
                            track.lyrics = Lyrics.normalized(draft)
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    draft = track.lyrics ?? ""
                    isFocused = draft.isEmpty
                }
                .onChange(of: draft) {
                    // Правка руками — «не нашлось» уже не о том, что на экране.
                    if lookup != .searching { lookup = .idle }
                }
        }
        // Плеер навязывает своим листам схему по обложке: тёмная обложка —
        // белый текст. Системный фон листа об этом не знает и остаётся светлым,
        // и текст пропадал — белое на белом. Материал, как у очереди и ремикса,
        // берёт схему вместе с текстом.
        .presentationBackground(.regularMaterial)
    }

    /// Поиск в LRCLIB. Найденное ложится в черновик, а не в трек: здесь
    /// уже может быть свой текст, и решать, менять ли его, — кнопкам
    /// «SAVE» и «SCRAP». Так же можно заменить обычный текст синхронным.
    private var findButton: some View {
        Button {
            find()
        } label: {
            HStack(spacing: 5) {
                if lookup == .searching {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                }
                Text("FIND")
                    .tracking(1.2)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tint)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(lookup == .searching)
        .accessibilityLabel("Find lyrics on LRCLIB")
    }

    private func find() {
        let query = LyricsLookup.Query(track: track)
        lookup = .searching
        isFocused = false

        Task {
            lookup = await LyricsLookupStatus.run(query) { text in
                draft = text
            }
        }
    }
}
