import SwiftUI

/// Фон играющего трека: два цвета обложки, и второй «дышит» громкостью поверх первого.
///
/// Вынесен из плеера отдельным типом, потому что показывает его не только плеер:
/// экран артиста, открытый изнутри плеера, продолжает тот же фон.
struct PlayerBackground: View {

    let audioPlayer: AudioPlayer

    var body: some View {
        // Обложки нет — красить нечем, остаётся чёрный.
        if audioPlayer.currentTrack?.displayArtwork == nil {
            Color.black
        } else {
            ZStack {
                // Дно: цвета лежат поверх чёрного, иначе на просвет было бы видно
                // то, что под плеером.
                Color.black

                ZStack {
                    // Не заливка одним тоном: к низу цвет отступает, и экран
                    // перестаёт выглядеть куском крашеной бумаги.
                    LinearGradient(
                        colors: [audioPlayer.accent, audioPlayer.accent.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Эллипс, а не круг: он тянется по форме экрана. Радиус задан
                    // долями кадра, поэтому пятно одинаково на любом устройстве.
                    EllipticalGradient(
                        colors: [
                            audioPlayer.secondaryAccent.opacity(0.35 + punch * 0.6),
                            audioPlayer.secondaryAccent.opacity(0)
                        ],
                        center: .center,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.6
                    )
                    .scaleEffect(0.9 + punch * 0.8) // на громком второй цвет наплывает
                    .blur(radius: 40)               // и растворяется в первом
                }
                .saturation(0.9 + punch * 1.1)      // вспыхивает цветом
                .hueRotation(.degrees(punch * 14))  // оттенок ведёт — фон «переливается»

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.9 - punch * 0.7)     // вуаль тончает, цвета проступают
            }
            // Анимация привязана к самим цветам: на смене трека они перетекают
            // друг в друга, а на «дыхании» не срабатывает — иначе каждый удар
            // громкости тянулся бы полсекунды.
            .animation(.easeInOut(duration: 0.6), value: audioPlayer.accent)
            .animation(.easeInOut(duration: 0.6), value: audioPlayer.secondaryAccent)
        }
    }

    private var punch: Double { audioPlayer.punch }
}

extension EnvironmentValues {
    /// Экран открыт изнутри плеера. По этому флагу вложенные экраны решают,
    /// продолжать ли фон плеера: в библиотеке и поиске у них фон обычный.
    ///
    /// `@Entry` — короткая запись для своего ключа environment: без него пришлось бы
    /// объявлять отдельный тип с `defaultValue`.
    @Entry var isInsidePlayer: Bool = false
}
