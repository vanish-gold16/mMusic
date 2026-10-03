import SwiftUI

/// Обложки плейлиста веером, как карты в руке: своя обложка впереди, за ней —
/// обложки треков. Плейлист — это подборка разного, и одна квадратная картинка
/// по центру (как у альбома) этого не говорит; несколько выглядывающих — говорят.
struct CoverFan: View {

    /// Спереди назад, не больше трёх.
    let covers: [UIImage]
    var size: CGFloat = 168

    /// На сколько каждая следующая карта выглядывает из-за предыдущей.
    /// Всё задано долями `size`: веер один и тот же и в шапке плейлиста,
    /// и в строке библиотеки, только меньше.
    private var spread: CGFloat { size * 0.26 }
    private var cornerRadius: CGFloat { size * 0.085 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if covers.isEmpty {
                card {
                    Image(systemName: "music.note.list")
                        .font(.system(size: size * 0.26))
                        .foregroundStyle(.secondary)
                }
            }

            // Задние рисуются первыми, чтобы передняя легла поверх.
            ForEach(Array(covers.enumerated()).reversed(), id: \.offset) { index, image in
                card {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                // Поворот вокруг нижнего левого угла раскрывает карты вправо,
                // как веер; уменьшение уводит задние вглубь.
                .scaleEffect(1 - CGFloat(index) * 0.08, anchor: .bottomLeading)
                .rotationEffect(.degrees(Double(index) * 7), anchor: .bottomLeading)
                .offset(x: CGFloat(index) * spread)
            }
        }
        // Ширина с запасом под повёрнутые задние карты: иначе они вылезали бы
        // за рамку, и соседний текст наезжал бы на них.
        .frame(width: size + spread * 2 + size * 0.19, height: size, alignment: .bottomLeading)
        .accessibilityHidden(true)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)
            .frame(width: size, height: size)
            .overlay(content: content)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: size * 0.06, y: size * 0.035)
    }
}
