import SwiftUI

/// Правка статического текста трека. Открывается листом и из плеера, и из
/// редактора трека — поэтому свой `NavigationStack` носит с собой.
struct LyricsEditorView: View {

    let track: Track

    @Environment(\.dismiss) private var dismiss

    /// Черновик: SwiftData пишет изменение модели в базу сразу, и правь мы
    /// `track.lyrics` напрямую, кнопке «Cancel» нечего было бы отменять.
    @State private var draft = ""
    /// Клавиатура поднимается сама, когда текста ещё нет: пустой экран открывают,
    /// чтобы писать, а не чтобы смотреть.
    @FocusState private var isFocused: Bool

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
                .navigationTitle(track.name)
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
