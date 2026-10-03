import SwiftUI

/// Обложки плейлиста: главная крупно, а из-за её правого края ступенькой вверх
/// выглядывают две маленькие — обложки треков. Плейлист — это подборка разного,
/// и одна квадратная картинка по центру (как у альбома) этого не говорит.
///
/// Главная — своя обложка плейлиста, а если её нет, обложка первого трека.
/// Задние заметно меньше и чуть притенены: при равных размерах веер читался
/// как колода одинаковых карт, и глаз не знал, на какую смотреть.
struct CoverFan: View {

    /// Спереди назад, не больше трёх. Первая — главная.
    let covers: [UIImage]
    var size: CGFloat = 168

    /// Задние карты по порядку: размер, где стоит левый край, насколько поднят
    /// низ и наклон. Всё — доли `size`, поэтому веер один и тот же и в шапке
    /// плейлиста, и в строке библиотеки, только меньше.
    private struct Placement {
        let scale: CGFloat
        let leading: CGFloat
        let lift: CGFloat
        let angle: Double
    }

    private static let placements = [
        Placement(scale: 0.62, leading: 0.62, lift: 0.12, angle: 7),
        Placement(scale: 0.48, leading: 0.98, lift: 0.26, angle: 14),
    ]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if covers.isEmpty {
                card(side: size, isMain: true) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: size * 0.26))
                        .foregroundStyle(.secondary)
                }
            }

            // Задние рисуются первыми, чтобы главная легла поверх.
            ForEach(Array(covers.prefix(3).enumerated()).reversed(), id: \.offset) { index, image in
                if index == 0 {
                    card(side: size, isMain: true) { cover(image) }
                } else {
                    let placement = Self.placements[index - 1]

                    card(side: size * placement.scale, isMain: false) { cover(image) }
                        // Поворот вокруг нижнего левого угла наклоняет карту вправо,
                        // как карту в руке.
                        .rotationEffect(.degrees(placement.angle), anchor: .bottomLeading)
                        .offset(x: size * placement.leading, y: -size * placement.lift)
                }
            }
        }
        // Ширина одна при любом числе обложек: в списке плейлистов по ней
        // выравниваются имена, и строка с одной обложкой не должна их сдвигать.
        .frame(width: size * 1.62, height: size, alignment: .bottomLeading)
        .accessibilityHidden(true)
    }

    private func cover(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
    }

    private func card<Content: View>(side: CGFloat, isMain: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.09, style: .continuous)

        return shape
            .fill(.quaternary)
            .frame(width: side, height: side)
            .overlay(content: content)
            // Задние уходят в тень, чтобы главная была первой, куда смотрит глаз.
            .overlay(Color.black.opacity(isMain ? 0 : 0.12))
            .clipShape(shape)
            // Тонкая светлая кромка: на тёмном фоне тёмная обложка иначе
            // сливается с ним краями.
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
            .shadow(
                color: .black.opacity(isMain ? 0.28 : 0.18),
                radius: side * (isMain ? 0.08 : 0.05),
                y: side * 0.04
            )
    }
}
