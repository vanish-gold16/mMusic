import SwiftUI

/// Пустое место в стопке строк: пунктир той же формы, что и строки вокруг.
/// Говорит «сюда можно что-то положить», не притворяясь ещё одной строкой.
struct DashedSlot: View {

    let title: String
    var systemImage = "plus"
    /// Крупный слот — когда кроме него на экране делать нечего.
    var isLarge = false
    /// Под форму соседних строк: у строк трека это капсула, у плейлистов — карточка.
    var cornerRadius: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: isLarge ? 120 : 60)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
