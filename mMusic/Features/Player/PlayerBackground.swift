import SwiftUI

/// Фон играющего трека: два цвета его обложки, из которых второй «дышит» громкостью.
///
/// Цвета не подбираются под обложку, а берутся из неё (см. `CoverPalette`), поэтому
/// тёмный альбом даёт тёмный экран, а выцветший — выцветший.
///
/// Живёт отдельным типом, потому что показывает его не только плеер: экран артиста,
/// открытый изнутри плеера, продолжает тот же фон.
struct PlayerBackground: View {

    let audioPlayer: AudioPlayer

    private var palette: CoverPalette { audioPlayer.palette }
    private var punch: Double { audioPlayer.punch }

    /// Чем гасить блики: на светлой обложке фон притеняется белым, на тёмной — чёрным.
    /// Тот же цвет, что и у текста поверх, поэтому вуаль не пачкает оттенок.
    private var scrim: Color { palette.isLight ? .white : .black }

    /// Сколько вуали нужно. Она страхует читаемость текста, а значит, нужна только
    /// на середине шкалы: на почти чёрном фоне белые буквы видно и так, на почти
    /// белом — чёрные. Раньше вуаль лежала одинаковой плотной пеленой, и тёмная
    /// обложка превращалась в чернильную дыру.
    private var scrimOpacity: Double {
        let risk = palette.isLight
            ? max(0.85 - palette.baseLuminance, 0)
            : max(palette.baseLuminance - 0.12, 0)

        // На громком вуаль тончает — цвета вспыхивают.
        return min(risk * 0.8, 0.34) * (1 - punch * 0.75)
    }

    var body: some View {
        ZStack {
            // Главный цвет обложки во весь экран.
            palette.base

            // Лёгкая глубина к низу: ровная заливка выглядит куском крашеной бумаги.
            LinearGradient(
                colors: [scrim.opacity(0), scrim.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Второй цвет обложки. Эллипс, а не круг: он тянется по форме экрана,
            // а радиус задан долями кадра — значит, пятно одинаково на любом устройстве.
            EllipticalGradient(
                colors: [
                    palette.secondary.opacity(0.55 + punch * 0.35),
                    palette.secondary.opacity(0)
                ],
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.6
            )
            .scaleEffect(0.9 + punch * 0.8)     // на громком второй цвет наплывает
            .blur(radius: 40)                   // и растворяется в первом
            .saturation(1 + punch * 0.9)        // вспыхивает цветом
            .hueRotation(.degrees(punch * 10))  // оттенок ведёт — фон «переливается»

            // Вуаль ровно на столько, чтобы читался текст. Раньше здесь лежало
            // толстое матовое стекло, и от цветов обложки оставался серый намёк.
            scrim.opacity(scrimOpacity)
        }
        // Анимация привязана к самой палитре: на смене трека цвета перетекают
        // друг в друга, а на «дыхании» не срабатывает — иначе каждый удар
        // громкости тянулся бы полсекунды.
        .animation(.easeInOut(duration: 0.6), value: palette)
    }
}

extension EnvironmentValues {
    /// Экран открыт изнутри плеера. По этому флагу вложенные экраны решают,
    /// продолжать ли фон плеера: в библиотеке и поиске у них фон обычный.
    ///
    /// `@Entry` — короткая запись для своего ключа environment: без него пришлось бы
    /// объявлять отдельный тип с `defaultValue`.
    @Entry var isInsidePlayer: Bool = false
}

extension View {

    /// Экран, открытый изнутри плеера, продолжает его фон, а не встаёт
    /// непрозрачным прямоугольником. В библиотеке и поиске фон не трогается.
    func insidePlayerBackground() -> some View {
        modifier(InsidePlayerBackground())
    }
}

private struct InsidePlayerBackground: ViewModifier {

    @Environment(\.isInsidePlayer) private var isInsidePlayer
    @Environment(AudioPlayer.self) private var audioPlayer

    func body(content: Content) -> some View {
        // `containerBackground`, а не `background`: у вложенного экрана своя
        // непрозрачная подложка, и закрасить её можно только фоном контейнера.
        if isInsidePlayer {
            content
                .containerBackground(for: .navigation) {
                    PlayerBackground(audioPlayer: audioPlayer)
                }
        } else {
            content
        }
    }
}
