import SwiftUI

/// Крутилка с пульта. Значение меняется движением пальца вверх-вниз, а не по кругу:
/// пальцем по дуге не попасть, а вертикальным ходом выходит точнее — так сделано
/// и на железных пультах, и в звуковых приложениях.
///
/// Двойное касание возвращает ручку в исходное положение.
struct KnobView: View {

    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Куда возвращает двойное касание.
    let neutral: Double
    let accent: Color
    /// Как подписать текущее значение: «0.85×», «−3 st», «45%».
    let caption: (Double) -> String
    var isEnabled = true
    /// Палец на ручке. По нему лист запрещает себе закрываться, иначе движение
    /// вниз по ручке утащило бы за собой всю панель.
    var onAdjustingChange: (Bool) -> Void = { _ in }

    /// Шкала проходится целиком за 180 точек хода — привычная чувствительность
    /// для такого размера ручки.
    private var sensitivity: Double {
        (range.upperBound - range.lowerBound) / 180
    }

    /// Значение на момент касания: считать от него, а не от текущего, иначе
    /// движение накапливает само себя и ручка убегает.
    @State private var startValue: Double?

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    private static let size: CGFloat = 78
    /// Дуга занимает три четверти круга с разрывом внизу — там, где у ручки
    /// «мёртвая зона» между началом и концом шкалы.
    private static let sweep: Double = 0.75

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .trim(from: 0, to: Self.sweep)
                    .stroke(Color.primary.opacity(0.15), style: .init(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: Self.sweep * fraction)
                    .stroke(accent, style: .init(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Указатель едет по той же дуге: смещаем точку вверх и поворачиваем
                // вокруг центра — от −135° (левый низ) до +135° (правый низ).
                Circle()
                    .fill(accent)
                    .frame(width: 9, height: 9)
                    .offset(y: -Self.size / 2 + 2.5)
                    .rotationEffect(.degrees(-135 + 270 * fraction))

                Text(caption(value))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
            }
            .frame(width: Self.size, height: Self.size)
            .contentShape(Circle())
            // Ручка — своя фигура без стандартного управления, поэтому и имя,
            // и значение для тестов и озвучки задаются вручную.
            .accessibilityIdentifier("knob-\(title)")
            .accessibilityValue(caption(value))
            .gesture(drag)
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { value = neutral }
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(isEnabled)
        .animation(.linear(duration: 0.08), value: value)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                if startValue == nil {
                    startValue = value
                    onAdjustingChange(true)
                }

                // Вверх — больше: экран растёт вниз, поэтому смещение вычитается.
                let next = (startValue ?? value) - gesture.translation.height * sensitivity
                value = min(max(next, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                startValue = nil
                onAdjustingChange(false)
            }
    }
}
