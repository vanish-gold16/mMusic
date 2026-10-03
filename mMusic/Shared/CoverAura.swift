import SwiftUI

/// Фон страницы с обложкой: обычный фон экрана и над ним, у верхнего края,
/// свечение двумя цветами обложки. Текст лежит на почти чистом фоне и читается
/// в обеих темах, а цвет у страницы всё равно свой. Стоит у плейлиста и у формы
/// импорта трека.
///
/// Пока играет плейлист, цвета берутся у играющего трека и свечение дышит
/// громкостью — как фон плеера. Громкость читается здесь, а не на самом экране:
/// она меняется 30 раз в секунду, и перерисовываться должен только фон.
struct CoverAura: View {

    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.colorScheme) private var colorScheme

    /// nil — у плейлиста нет ни одной обложки, светиться нечем.
    let palette: CoverPalette?
    /// Дышать ли под музыку: только когда играет то, что на экране.
    let breathes: Bool

    /// На белом цвет заметнее, чем на чёрном, — светлой теме хватает меньшего.
    private var strength: Double {
        colorScheme == .dark ? 0.55 : 0.38
    }

    var body: some View {
        // `punch` читается только при `breathes`: иначе любой открытый плейлист
        // перерисовывался бы под чужую музыку.
        let punch = breathes && audioPlayer.isPlaying ? audioPlayer.punch : 0

        ZStack(alignment: .top) {
            Color(.systemBackground)

            if let palette {
                // Градиенты, а не размытые круги: размытие пересчитывалось бы
                // на каждом вдохе, а градиент ничего не стоит. Высота рамки
                // ограничена, потому что эллипс градиента вписывается в неё:
                // во весь экран свечение стекало бы до середины списка.
                ZStack {
                    EllipticalGradient(
                        colors: [palette.accent.opacity(strength + punch * 0.25), .clear],
                        center: UnitPoint(x: 0.1, y: 0),
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.75 + punch * 0.15
                    )

                    EllipticalGradient(
                        colors: [palette.secondary.opacity(strength * 0.8 + punch * 0.2), .clear],
                        center: UnitPoint(x: 0.95, y: 0.12),
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.55 + punch * 0.15
                    )
                }
                .frame(height: 560)
            }
        }
        .ignoresSafeArea()
        // Анимация привязана к палитре: на смене трека цвета перетекают,
        // а на дыхании не тянутся — иначе каждый удар запаздывал бы.
        .animation(.easeInOut(duration: 0.6), value: palette)
    }
}
