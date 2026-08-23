import SwiftUI

/// Текст играющего трека на месте обложки. Под ним остаются и ползунок, и кнопки:
/// читать можно, не теряя управления и не уходя с экрана.
///
/// Карточки и матового стекла нет намеренно — текст лежит прямо на «дышащем» фоне
/// плеера, как и остальное его содержимое, и растворяется у краёв вместо обрыва.
struct LyricsPanel: View {

    let text: String
    let accent: Color
    /// Открыть редактор. Нужен, пока текста нет: пустая панель должна не просто
    /// сообщать о пустоте, а предлагать её заполнить.
    let onEdit: () -> Void

    private var stanzas: [String] { Lyrics.stanzas(of: text) }

    var body: some View {
        Group {
            if stanzas.isEmpty {
                empty
            } else {
                scroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Куплеты — просто куски текста, своего id у них нет, поэтому
                // ForEach считает по позиции.
                ForEach(Array(stanzas.enumerated()), id: \.offset) { _, stanza in
                    Text(stanza)
                        .lineSpacing(6)
                }
            }
            .font(.title3.weight(.semibold))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        // Маска гасит текст у краёв: видно, что он продолжается, а строка не
        // обрубается ровно пополам о невидимую границу.
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.07),
                    .init(color: .black, location: 0.93),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No text yet")
                .font(.headline)

            Text("Lyrics, a translation or a note — whatever you want to read while this track plays.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Add text", action: onEdit)
                .buttonStyle(.glassProminent)
                .tint(accent)
                .padding(.top, 4)
        }
        .padding(.horizontal, 8)
    }
}
