import SwiftUI

/// Микс главной — кассета. Альбом в приложении — пластинка, плейлист — веер
/// карт, а случайная подборка, которую приложение записало для тебя, —
/// микстейп: так подборки и дарили, пока не было стриминга.
///
/// Корпус прозрачный, из стекла, как у прозрачных кассет и у всего интерфейса.
/// В окошке видно ленту: пока играет микс, катушки крутятся, и плёнка
/// перематывается с левой на правую по мере того, как микс идёт.
struct Cassette: View {

    let title: String
    /// Номер кассеты на наклейке. 0 — номера нет.
    let number: Int
    /// Строка под окошком: «25 TRACKS  ·  1 H 32 MIN».
    let detail: String
    /// Цвета наклейки — первой обложки микса. nil — серые полосы.
    let palette: CoverPalette?
    /// Сколько ленты перемотано, 0...1.
    let progress: Double
    let isSpinning: Bool

    /// Пропорции настоящей компакт-кассеты: 100 × 63,8 мм.
    static let aspectRatio: CGFloat = 1.57

    var body: some View {
        Color.clear
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let size = proxy.size
                    let shape = RoundedRectangle(cornerRadius: size.width * 0.045, style: .continuous)

                    ZStack(alignment: .top) {
                        screws(size)
                        bottomPlate(size)

                        label(size)
                            .padding(.top, size.height * 0.07)
                            .padding(.horizontal, size.width * 0.055)
                    }
                    .frame(width: size.width, height: size.height)
                    .glassEffect(.regular.tint((palette?.base ?? .gray).opacity(0.18)), in: shape)
                }
            }
    }

    // MARK: - Наклейка

    private func label(_ size: CGSize) -> some View {
        let width = size.width * 0.89
        let height = size.height * 0.64
        let shape = RoundedRectangle(cornerRadius: size.width * 0.025, style: .continuous)

        return ZStack(alignment: .topLeading) {
            // Белая бумага в светлой теме, тёмно-серая — в тёмной: на чёрной
            // наклейке тёмное окошко с катушками пропадало бы.
            shape.fill(Color(.tertiarySystemBackground).opacity(0.92))

            stripes(width: width, height: height)
                .offset(y: height * 0.5)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: height * 0.19, weight: .heavy).width(.compressed))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if number > 0 {
                    Text("No. \(number)")
                        .font(.system(size: height * 0.13, weight: .heavy).width(.compressed))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("A")
                    .font(.system(size: height * 0.19, weight: .heavy).width(.compressed))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, width * 0.05)
            .padding(.top, height * 0.06)

            window(width: width * 0.62, height: height * 0.36)
                .offset(x: width * 0.19, y: height * 0.38)

            Text(detail)
                .font(.system(size: max(9, height * 0.075), weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: width * 0.9)
                .offset(x: width * 0.05, y: height * 0.82)
        }
        .frame(width: width, height: height)
        .clipShape(shape)
    }

    /// Две цветные полосы через всю наклейку, под окошком — как у кассет
    /// восьмидесятых. Цвета — первой обложки микса.
    private func stripes(width: CGFloat, height: CGFloat) -> some View {
        let first = palette?.accent ?? Color(white: 0.55)
        let second = palette?.secondary ?? Color(white: 0.75)

        return VStack(spacing: height * 0.02) {
            Rectangle().fill(first)
                .frame(height: height * 0.07)
            Rectangle().fill(second)
                .frame(height: height * 0.07)
        }
        .frame(width: width)
    }

    // MARK: - Окошко с катушками

    private func window(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.animation(paused: !isSpinning)) { context in
            Canvas { canvas, size in
                drawWindow(in: &canvas, size: size, date: context.date)
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func drawWindow(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let frame = CGRect(origin: .zero, size: size)
        let windowShape = Path(roundedRect: frame, cornerRadius: size.height * 0.28, style: .continuous)
        context.fill(windowShape, with: .color(Color(white: 0.08).opacity(0.88)))
        context.stroke(windowShape, with: .color(.white.opacity(0.12)), lineWidth: 1)

        let left = CGPoint(x: size.width * 0.22, y: size.height / 2)
        let right = CGPoint(x: size.width * 0.78, y: size.height / 2)
        let hub = size.height * 0.2
        // Полная катушка почти касается краёв окошка, но не вылезает за них.
        let fullPack = size.height * 0.45
        let emptyPack = hub * 1.15

        // Лента сматывается с левой катушки на правую. Радиус — по площади
        // намотки, а не линейно: так катушки меняются, как настоящие.
        let fraction = min(max(progress, 0), 1)
        let leftPack = packRadius(full: fullPack, empty: emptyPack, share: 1 - fraction)
        let rightPack = packRadius(full: fullPack, empty: emptyPack, share: fraction)

        let angle = Angle.degrees(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 360)

        for (center, pack) in [(left, leftPack), (right, rightPack)] {
            func circle(_ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }

            context.fill(circle(pack), with: .color(Color(red: 0.24, green: 0.16, blue: 0.11)))
            context.stroke(circle(pack), with: .color(.white.opacity(0.08)), lineWidth: 0.5)
            context.fill(circle(hub), with: .color(Color(white: 0.92)))

            // Зубцы втулки — по ним видно, что катушка крутится.
            var teeth = context
            teeth.translateBy(x: center.x, y: center.y)
            teeth.rotate(by: angle)
            for tooth in 0..<6 {
                var copy = teeth
                copy.rotate(by: .degrees(Double(tooth) * 60))
                let rect = CGRect(x: -hub * 0.12, y: -hub * 0.62, width: hub * 0.24, height: hub * 0.34)
                copy.fill(Path(rect), with: .color(Color(white: 0.08)))
            }
            teeth.fill(
                Path(ellipseIn: CGRect(x: -hub * 0.3, y: -hub * 0.3, width: hub * 0.6, height: hub * 0.6)),
                with: .color(Color(white: 0.08))
            )
        }
    }

    private func packRadius(full: CGFloat, empty: CGFloat, share: Double) -> CGFloat {
        (empty * empty + (full * full - empty * empty) * CGFloat(share)).squareRoot()
    }

    // MARK: - Корпус

    private func screws(_ size: CGSize) -> some View {
        let inset = size.width * 0.028
        let side = size.width * 0.018

        return ZStack {
            ForEach(0..<4, id: \.self) { corner in
                Circle()
                    .strokeBorder(.secondary.opacity(0.6), lineWidth: 0.75)
                    .frame(width: side, height: side)
                    .position(
                        x: corner % 2 == 0 ? inset : size.width - inset,
                        y: corner < 2 ? inset : size.height - inset
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// Трапеция снизу с окнами под головку и ролики.
    private func bottomPlate(_ size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let width = canvasSize.width
            let height = canvasSize.height

            var plate = Path()
            plate.move(to: CGPoint(x: width * 0.2, y: height))
            plate.addLine(to: CGPoint(x: width * 0.25, y: height * 0.78))
            plate.addLine(to: CGPoint(x: width * 0.75, y: height * 0.78))
            plate.addLine(to: CGPoint(x: width * 0.8, y: height))
            context.stroke(plate, with: .color(.secondary.opacity(0.45)), lineWidth: 1)

            let hole = height * 0.06
            for x in [width * 0.36, width * 0.64] {
                let rect = CGRect(x: x - hole / 2, y: height * 0.87, width: hole, height: hole)
                context.stroke(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.5)), lineWidth: 1)
            }

            let slot = CGSize(width: height * 0.05, height: height * 0.05)
            for x in [width * 0.3, width * 0.7] {
                let rect = CGRect(origin: CGPoint(x: x - slot.width / 2, y: height * 0.88), size: slot)
                context.fill(Path(rect), with: .color(.secondary.opacity(0.35)))
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}
