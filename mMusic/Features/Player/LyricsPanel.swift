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
            // Выделение текста — цветом обложки, как всё остальное в плеере.
            .tint(accent)
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

    /// Пустая панель не просто сообщает о пустоте, а предлагает её заполнить —
    /// пунктирным слотом, как везде в приложении, где «сюда можно что-то положить».
    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NO TEXT YET")
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)

            Text("Lyrics, a translation or a note — whatever you want to read while this track plays.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DashedSlot(title: "Add text", systemImage: "text.quote", action: onEdit)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
