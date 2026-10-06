import SwiftUI

/// Круглая наклейка на обложке автоподборки — как «HEAVY ROTATION» или
/// «JUST IN» на пластинках в магазине. По ней автоподборку отличают от плейлиста,
/// собранного руками: у того наклейки нет.
///
/// Бумага кремовая, буквы чёрные — наклейка читается на любой обложке и в любой
/// теме; цвет страницы ей достаётся только тонким кольцом. Там, где буквы
/// были бы мельче читаемого, вместо надписи — значок.
struct HypeSticker: View {

    let text: String
    let systemImage: String
    let accent: Color

    private static let paper = Color(red: 0.98, green: 0.95, blue: 0.86)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(Self.paper)

                Circle()
                    .stroke(accent, lineWidth: max(side * 0.045, 1))
                    .padding(side * 0.08)

                if side >= 56 {
                    Text(text)
                        .font(.system(size: side * 0.19, weight: .heavy).width(.compressed))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .padding(side * 0.18)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: side * 0.42, weight: .bold))
                }
            }
            .foregroundStyle(.black.opacity(0.85))
            .frame(width: side, height: side)
            // Наклеена от руки — чуть криво.
            .rotationEffect(.degrees(-12))
            .shadow(color: .black.opacity(0.25), radius: side * 0.04, x: 0, y: side * 0.02)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(text.replacingOccurrences(of: "\n", with: " ").capitalized)
    }
}

extension View {

    /// Наклейка на правом верхнем углу главной карты веера `CoverFan`
    /// размера `size`: чуть заходит за край, как наклеенная на угол конверта.
    func hypeSticker(_ playlist: SmartPlaylist, accent: Color, fanSize size: CGFloat) -> some View {
        let side = size * 0.46

        // Веер выровнен по низу, главная карта — квадрат `size` в его левом нижнем углу.
        return overlay(alignment: .bottomLeading) {
            HypeSticker(text: playlist.sticker, systemImage: playlist.systemImage, accent: accent)
                .frame(width: side, height: side)
                .offset(x: size - side * 0.85, y: -(size - side * 0.85))
        }
    }
}
