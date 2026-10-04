import SwiftUI

/// Проигрыватель, увиденный сверху: опорный диск, на нём пластинка играющего
/// альбома и тонарм. В библиотеке пластинка выглядывает из конверта, на главной
/// она уже лежит на диске и играет.
///
/// Тонарм — это и есть полоса прогресса: игла стоит там, где на пластинке
/// звучит музыка, и за альбом проходит путь от края к яблоку, как на настоящем
/// виниле. На паузе рычаг уходит на стойку, по нажатию «play» возвращается.
///
/// Диск — тот же `VinylRecord`, что в конверте: кольца — треки пластинки,
/// текущее горит акцентом, нажатие на кольцо ставит трек или перематывает.
struct Turntable: View {

    let cover: UIImage?
    let type: Album.AlbumType
    /// Длительности треков пластинки по порядку. 0 — ещё не прочитана.
    let durations: [TimeInterval]
    let currentIndex: Int
    /// Сколько сыграно у текущего трека, 0...1.
    let progress: Double
    let isPlaying: Bool
    let accent: Color
    var onTapTrack: ((_ index: Int, _ fraction: Double) -> Void)? = nil

    /// Ширина к высоте. Справа от диска — место под тонарм и его стойку.
    static let aspectRatio: CGFloat = 1.22

    var body: some View {
        Color.clear
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let geometry = Geometry(height: proxy.size.height, type: type)

                    ZStack(alignment: .topLeading) {
                        platter(geometry)
                        record(geometry)
                        armRest(geometry)
                        arm(geometry)
                        pivot(geometry)
                        speed(geometry)
                    }
                }
            }
    }

    // MARK: - Детали

    private func platter(_ geometry: Geometry) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.11)))

            // Стробоскопические точки по краю — как у настоящего диска.
            // Под лампой стробоскопа они стоят на месте, поэтому и здесь неподвижны.
            let dot = max(1.2, radius * 0.012)
            for step in 0..<120 {
                let angle = Double(step) / 120 * 2 * .pi
                let point = CGPoint(
                    x: center.x + cos(angle) * radius * 0.975,
                    y: center.y + sin(angle) * radius * 0.975
                )
                let rect = CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.22)))
            }

            context.stroke(
                Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 0.25, dy: 0.25)),
                with: .color(.white.opacity(0.16)),
                lineWidth: 0.5
            )
        }
        .frame(width: geometry.platterRadius * 2, height: geometry.platterRadius * 2)
        .shadow(color: .black.opacity(0.3), radius: geometry.height * 0.04, y: geometry.height * 0.02)
        .offset(x: geometry.center.x - geometry.platterRadius, y: geometry.center.y - geometry.platterRadius)
        .accessibilityHidden(true)
    }

    private func record(_ geometry: Geometry) -> some View {
        VinylRecord(
            cover: cover,
            durations: durations,
            currentIndex: currentIndex,
            progress: progress,
            isSpinning: isPlaying,
            rpm: type.rpm,
            labelFraction: type.labelFraction,
            accent: accent,
            onTapTrack: onTapTrack
        )
        .frame(width: geometry.recordRadius * 2, height: geometry.recordRadius * 2)
        // Пластинка на диске отбрасывает лёгкую тень — так видно, что она лежит
        // сверху, а не нарисована на нём.
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .offset(x: geometry.center.x - geometry.recordRadius, y: geometry.center.y - geometry.recordRadius)
    }

    /// Стойка, на которой рычаг лежит на паузе.
    private func armRest(_ geometry: Geometry) -> some View {
        let rest = geometry.stylus(atAngle: Geometry.restAngle)
        let width = geometry.height * 0.05

        return Capsule()
            .fill(Color(white: 0.22))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            .frame(width: width, height: width * 0.5)
            .offset(x: rest.x - width / 2, y: rest.y - geometry.headLength * 1.4)
            .accessibilityHidden(true)
    }

    private func arm(_ geometry: Geometry) -> some View {
        // На паузе — на стойке. Играет — там, где игла на пластинке.
        let angle = isPlaying ? geometry.angle(forDistance: stylusDistance(geometry)) : Geometry.restAngle

        return Tonearm(geometry: geometry)
            .frame(width: geometry.armWidth, height: geometry.armLength + geometry.counterLength)
            .rotationEffect(.degrees(angle), anchor: UnitPoint(
                x: 0.5,
                y: geometry.counterLength / (geometry.armLength + geometry.counterLength)
            ))
            .shadow(color: .black.opacity(isPlaying ? 0.35 : 0.25), radius: isPlaying ? 3 : 5, x: 2, y: isPlaying ? 3 : 6)
            .offset(x: geometry.pivot.x - geometry.armWidth / 2, y: geometry.pivot.y - geometry.counterLength)
            // Рычаг переезжает плавно, только когда его поднимают или ставят и когда
            // меняется трек. Прогресс внутри трека ползёт сам: анимировать каждый
            // тик незачем, за пять секунд игла сдвигается на долю градуса.
            .animation(.spring(duration: 0.9, bounce: 0.12), value: isPlaying)
            .animation(.spring(duration: 0.6, bounce: 0.1), value: currentIndex)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func pivot(_ geometry: Geometry) -> some View {
        let radius = geometry.height * 0.065

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.42), Color(white: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(Color(white: 0.12))
                .padding(radius * 0.45)
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .frame(width: radius * 2, height: radius * 2)
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        .offset(x: geometry.pivot.x - radius, y: geometry.pivot.y - radius)
        .accessibilityHidden(true)
    }

    /// Скорость под стойкой, мелко: «33⅓» или «45».
    private func speed(_ geometry: Geometry) -> some View {
        Text(type == .single ? "45" : "33⅓")
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(.tertiary)
            .fixedSize()
            .frame(width: geometry.height * 0.3, alignment: .trailing)
            .offset(x: geometry.width - geometry.height * 0.3, y: geometry.height * 0.92)
            .accessibilityHidden(true)
    }

    // MARK: - Где игла

    /// Вес каждого трека — так же, как у колец `VinylRecord`, иначе игла
    /// и подсвеченное кольцо разошлись бы на треке с непрочитанной длительностью.
    private var weights: [Double] {
        let known = durations.filter { $0 > 0 }
        let fallback = known.isEmpty ? 180 : known.reduce(0, +) / Double(known.count)

        return durations.map { $0 > 0 ? $0 : fallback }
    }

    /// Расстояние от центра пластинки до иглы. Канавки идут от края к яблоку,
    /// и чем дальше по пластинке, тем ближе игла к центру.
    private func stylusDistance(_ geometry: Geometry) -> CGFloat {
        let weights = weights
        let total = weights.reduce(0, +)
        guard total > 0, weights.indices.contains(currentIndex) else { return geometry.grooveOuter }

        let played = weights[..<currentIndex].reduce(0, +) + weights[currentIndex] * min(max(progress, 0), 1)
        let fraction = CGFloat(played / total)

        return geometry.grooveOuter - (geometry.grooveOuter - geometry.grooveInner) * fraction
    }
}

// MARK: - Геометрия

extension Turntable {

    /// Все размеры проигрывателя — доли высоты, поэтому он одинаков на любом экране.
    struct Geometry {

        let height: CGFloat
        let type: Album.AlbumType

        var width: CGFloat { height * Turntable.aspectRatio }

        var platterRadius: CGFloat { height * 0.48 }
        var center: CGPoint { CGPoint(x: platterRadius + height * 0.02, y: height / 2) }

        /// Сингл на диске заметно меньше LP — как семидюймовка на проигрывателе,
        /// где обычно лежат двенадцатидюймовые.
        var recordRadius: CGFloat {
            switch type {
            case .single: platterRadius * 0.64
            case .EP: platterRadius * 0.82
            case .LP: platterRadius * 0.955
            }
        }

        /// Где идут канавки — те же доли, что у `VinylRecord`.
        var grooveOuter: CGFloat { recordRadius * 0.96 }
        var grooveInner: CGFloat { recordRadius * (type.labelFraction + 0.06) }

        /// Ось тонарма — в правом верхнем углу, за краем диска.
        var pivot: CGPoint { CGPoint(x: width - height * 0.1, y: height * 0.1) }

        /// Длина от оси до иглы. Подобрана так, чтобы игла доставала от края
        /// пластинки до яблока у любого формата и при этом не залезала на ось.
        var armLength: CGFloat { height * 0.6 }
        /// Противовес за осью.
        var counterLength: CGFloat { height * 0.13 }
        var armWidth: CGFloat { height * 0.09 }
        var headLength: CGFloat { height * 0.075 }

        /// Угол рычага на стойке: почти отвесно вниз, чуть от пластинки.
        static let restAngle: Double = -3

        /// Где игла, если рычаг повёрнут на `angle` градусов по часовой
        /// от отвесного положения.
        func stylus(atAngle angle: Double) -> CGPoint {
            let radians = angle * .pi / 180
            return CGPoint(
                x: pivot.x - sin(radians) * armLength,
                y: pivot.y + cos(radians) * armLength
            )
        }

        /// Угол, при котором игла стоит на расстоянии `distance` от центра
        /// пластинки. Это пересечение двух окружностей: игла лежит и на круге
        /// вокруг центра пластинки, и на круге длины рычага вокруг оси.
        /// Из двух точек пересечения берётся нижняя — рычаг свисает вниз.
        func angle(forDistance distance: CGFloat) -> Double {
            let dx = center.x - pivot.x
            let dy = center.y - pivot.y
            let span = hypot(dx, dy)

            let along = (armLength * armLength - distance * distance + span * span) / (2 * span)
            let across = (max(armLength * armLength - along * along, 0)).squareRoot()

            let ux = dx / span
            let uy = dy / span
            let middle = CGPoint(x: pivot.x + along * ux, y: pivot.y + along * uy)
            let stylus = CGPoint(x: middle.x + across * uy, y: middle.y - across * ux)

            return atan2(-(stylus.x - pivot.x), stylus.y - pivot.y) * 180 / .pi
        }
    }
}

/// Сам рычаг: противовес, трубка и головка с иглой. Рисуется отвесно, ось —
/// на высоте `counterLength` от верха; поворачивает его `Turntable`.
private struct Tonearm: View {

    let geometry: Turntable.Geometry

    private var metal: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.85), Color(white: 0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        let tube = max(2.5, geometry.height * 0.014)
        let counter = geometry.counterLength

        VStack(spacing: 0) {
            // Противовес выступает над осью.
            RoundedRectangle(cornerRadius: geometry.armWidth * 0.12, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.5), Color(white: 0.25)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: geometry.armWidth * 0.62, height: counter * 0.62)

            Capsule()
                .fill(metal)
                .frame(width: tube)
                .frame(maxHeight: .infinity)

            // Головка — чуть шире трубки, с тёмной иглой на конце.
            UnevenRoundedRectangle(
                topLeadingRadius: 2,
                bottomLeadingRadius: geometry.armWidth * 0.12,
                bottomTrailingRadius: geometry.armWidth * 0.12,
                topTrailingRadius: 2,
                style: .continuous
            )
            .fill(Color(white: 0.2))
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(Color(white: 0.85))
                    .frame(width: tube * 0.9, height: tube * 0.9)
                    .padding(.bottom, 1)
            }
            .frame(width: geometry.armWidth * 0.5, height: geometry.headLength)
        }
        .padding(.top, counter * 0.2)
        .frame(width: geometry.armWidth, height: geometry.armLength + counter, alignment: .top)
    }
}
