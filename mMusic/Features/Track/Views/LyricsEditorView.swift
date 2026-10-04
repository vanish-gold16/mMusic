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
    /// `track.lyrics` напрямую, кнопке «Cancel» нечего было бы отменять.
    @State private var draft = ""
    /// Клавиатура поднимается сама, когда текста ещё нет: пустой экран открывают,
    /// чтобы писать, а не чтобы смотреть.
    @FocusState private var isFocused: Bool

    /// «TEXT  ·  24 LINES». Пустые строки между куплетами не считаются.
    private var passport: [String] {
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
                        RecordPassport(parts: passport)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            track.lyrics = Lyrics.normalized(draft)
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    draft = track.lyrics ?? ""
                    isFocused = draft.isEmpty
                }
        }
    }
}
