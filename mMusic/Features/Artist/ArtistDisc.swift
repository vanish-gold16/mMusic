import SwiftData
import SwiftUI

/// Пластинка артиста: на яблоке его фотография, а кольца — его пластинки,
/// от первой снаружи к последней у яблока, как треки на диске альбома, только
/// в масштабе всей карьеры. Толщина кольца — длительность: альбом лежит широкой
/// дорожкой, сингл — тонкой. Кольцо того, что играет сейчас, горит акцентом.
///
/// Фотографии у артиста обычно нет — её ставят руками. Тогда яблоко бумажное,
/// как на настоящем виниле: цвета его обложек, с инициалами вместо лица.
/// Ряд одинаковых серых микрофонов в списке артистов ничего бы не различал.
///
/// Диск не крутится и всегда стоит ровно: лицо, бегущее по кругу со скоростью
/// 33 оборота в минуту, смотрелось бы аттракционом. Стоит в шапке страницы
/// артиста и в строке библиотеки.
struct ArtistDisc: View {

    @Environment(AudioPlayer.self) private var audioPlayer

    let name: String
    /// Пластинки в порядке колец, от первой к последней.
    let releases: [Album]
    /// Уменьшенная фотография; nil — фотографии нет, яблоко бумажное.
    let photo: UIImage?
    /// Цвет бумажного яблока. nil — обложек нет, цвет выводится из имени.
    let labelPaper: Color?
    let accent: Color
    /// Нажали на кольцо пластинки. Без него диск только показывает.
    var onTapRelease: ((Album) -> Void)? = nil

    /// Доля яблока в радиусе диска — крупнее, чем у пластинок: на нём лицо.
    static let labelFraction: CGFloat = 0.52

    var body: some View {
        // Играющая пластинка читается здесь: на смене трека перерисоваться
        // должен диск, а не весь экран вокруг него.
        let playingAlbum = audioPlayer.currentTrack?.album?.persistentModelID
        let currentIndex = releases.firstIndex { $0.persistentModelID == playingAlbum }

        VinylRecord(
            cover: photo,
            durations: releases.map { $0.tracks.reduce(0) { $0 + $1.duration } },
            currentIndex: currentIndex,
            progress: nil,
            isSpinning: false,
            rpm: Album.AlbumType.LP.rpm,
            labelFraction: Self.labelFraction,
            accent: accent,
            onTapTrack: onTapRelease.map { onTap in
                { index, _ in
                    guard releases.indices.contains(index) else { return }
                    onTap(releases[index])
                }
            },
            isUpright: true
        )
        .overlay {
            if photo == nil {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height) * Self.labelFraction

                    PrintedLabel(initials: Self.initials(of: name), paper: labelPaper ?? Self.paper(for: name))
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Нажатия идут сквозь наклейку в диск: по яблоку диск
                // и так не отвечает, а кнопку фотографии кладут поверх.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    /// Первые буквы двух первых слов: «The Weeknd» — «TW», «Kavinsky» — «K».
    static func initials(of name: String) -> String {
        let letters = name
            .split(whereSeparator: \.isWhitespace)
            .compactMap { word in word.first { $0.isLetter || $0.isNumber } }
            .prefix(2)
            .map { String($0).uppercased() }
            .joined()

        return letters.isEmpty ? String(name.prefix(1)) : letters
    }

    /// Свой цвет у каждого имени и один и тот же от запуска к запуску:
    /// `hashValue` в Swift меняется при каждом запуске.
    static func paper(for name: String) -> Color {
        let seed = name.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        return Color(hue: Double(seed % 360) / 360, saturation: 0.5, brightness: 0.78)
    }
}

/// Бумажное яблоко: цветная наклейка с инициалами над отверстием,
/// тонкой рамкой по краю и, если места хватает, оборотами под отверстием.
private struct PrintedLabel: View {

    let initials: String
    let paper: Color

    /// Краска по бумаге: на светлой — тёмная, на тёмной — светлая.
    private var ink: Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(paper).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

        return luminance > 0.6 ? Color.black.opacity(0.8) : Color.white.opacity(0.92)
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(paper)

                Circle()
                    .stroke(ink.opacity(0.3), lineWidth: max(side * 0.012, 0.5))
                    .padding(side * 0.07)

                Text(initials)
                    .font(.system(size: side * 0.36, weight: .heavy).width(.compressed))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: side * 0.7)
                    .offset(y: -side * 0.19)

                // Мелкая строка, как на настоящей наклейке, — только там, где её
                // можно прочесть: в строке списка она была бы точкой.
                if side >= 60 {
                    Text("33⅓ RPM")
                        .font(.system(size: side * 0.07, weight: .semibold))
                        .tracking(side * 0.01)
                        .offset(y: side * 0.17)
                }

                // Отверстие под шпиндель.
                Circle()
                    .fill(Color(white: 0.05))
                    .frame(width: side * 0.08, height: side * 0.08)
            }
            .foregroundStyle(ink)
            .frame(width: side, height: side)
        }
    }
}
