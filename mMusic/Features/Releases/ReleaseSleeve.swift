import SwiftUI

/// Новинка — пластинка, которую ещё не распечатали: обложка под плёнкой
/// и наклейка на углу, как в магазине на полке новых поступлений. Диск из неё
/// не выглядывает — его ещё не слушали, и в библиотеке его нет.
struct ReleaseSleeve: View {

    let release: RadarRelease
    let accent: Color
    var pixels: CGFloat = 360

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width

            RemoteCover(url: release.cover, pixels: pixels, cornerRadius: 3)
                .overlay { shrinkWrap }
                .shadow(color: .black.opacity(0.22), radius: side * 0.03, y: side * 0.015)
                .overlay(alignment: .topTrailing) {
                    HypeSticker(text: Self.sticker(for: release), systemImage: Self.symbol(for: release), accent: accent)
                        .frame(width: side * 0.42, height: side * 0.42)
                        .offset(x: side * 0.08, y: -side * 0.08)
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Плёнка: косой блик по обложке и светлая кромка.
    private var shrinkWrap: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0.25),
                        .init(color: .white.opacity(0.22), location: 0.42),
                        .init(color: .white.opacity(0), location: 0.55),
                        .init(color: .white.opacity(0.08), location: 0.8),
                        .init(color: .white.opacity(0), location: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
    }

    /// Что написано на наклейке: анонс — день выхода, фит — «FEAT.»,
    /// вышедшее за последние двое суток — «JUST OUT», остальное — «NEW».
    static func sticker(for release: RadarRelease, now: Date = .now) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let day = RadarLogic.date(of: release.releaseDay) ?? today

        if day > today {
            return day.formatted(.dateTime.weekday(.abbreviated).locale(.interface)).uppercased()
                + "\n" + day.formatted(.dateTime.day().locale(.interface))
        }
        if release.isFeature { return "FEAT." }
        if let days = calendar.dateComponents([.day], from: day, to: today).day, days <= 1 {
            return "JUST\nOUT"
        }
        return "NEW"
    }

    static func symbol(for release: RadarRelease) -> String {
        if (RadarLogic.date(of: release.releaseDay) ?? .distantPast) > .now { return "calendar" }
        return release.isFeature ? "person.2.fill" : "sparkles"
    }
}

/// Подписи релиза: «OCT 10  ·  SINGLE» и кто его выпустил.
enum ReleaseCaption {

    /// Без дня недели: на полке подпись шириной с конверт, и «THU, OCT 8 · SINGLE»
    /// в неё уже не влезает. День недели у анонса и так написан на наклейке.
    static func dayAndKind(_ release: RadarRelease) -> String {
        let day = RadarLogic.date(of: release.releaseDay).map {
            $0.formatted(.dateTime.month(.abbreviated).day().locale(.interface))
        }
        return [day, release.kind.label].compactMap { $0 }.joined(separator: "  ·  ").uppercased()
    }

    /// Кто: свой релиз — как подписан в каталоге; фит — наш артист и чей релиз.
    static func who(_ release: RadarRelease) -> String {
        guard release.isFeature else { return release.byline }
        return "\(release.libraryArtists.joined(separator: ", ")) on \(release.byline)"
    }
}
