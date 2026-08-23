import CoreImage
import UIKit

extension UIImage {
    /// Клетка сжатой обложки, разложенная на оттенок, насыщенность и яркость.
    /// Тип вложен в расширение: за его пределами он никому не нужен.
    private struct Swatch {
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
    }

    /// Два цвета, которыми обложка «звучит»: `primary` — самый выразительный,
    /// `secondary` — самый выразительный из тех, что заметно отличаются от него оттенком.
    ///
    /// Простое усреднение почти всегда даёт грязно-серый — яркое пятно тонет в фоне.
    /// Поэтому картинка сжимается в сетку, серые и почти чёрно-белые клетки выбрасываются,
    /// а из остальных выбираются эти двое.
    ///
    /// `nonisolated`, как и `averageBrightness`: интерфейс не трогает и должно
    /// считаться в фоновой задаче.
    nonisolated var accentColors: (primary: UIColor, secondary: UIColor)? {
        let swatches = colorSwatches()

        guard let primary = swatches.max(by: { $0.saturation < $1.saturation }) else { return nil }

        // Второй цвет обязан читаться как другой: оттенок разводится минимум на 30°
        // (0.08 круга), иначе поверх фона «дышал» бы почти тот же самый цвет.
        let secondary = swatches
            .filter { Self.hueDistance($0.hue, primary.hue) > 0.08 }
            .max { $0.saturation < $1.saturation }
            // Обложка одноцветная — второй цвет берётся соседним по кругу.
            // Противоположный смотрелся бы наклейкой, соседний — переливом.
            ?? Swatch(
                hue: (primary.hue + 0.1).truncatingRemainder(dividingBy: 1),
                saturation: primary.saturation,
                brightness: primary.brightness
            )

        return (Self.color(from: primary), Self.color(from: secondary))
    }

    /// Обложка, сжатая до сетки 16×16 и очищенная от всего, что акцентом быть не может.
    nonisolated private func colorSwatches() -> [Swatch] {
        guard let cgImage else { return [] }

        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)

        let input = CIImage(cgImage: cgImage)
        let scale = CGAffineTransform(
            scaleX: CGFloat(side) / input.extent.width,
            y: CGFloat(side) / input.extent.height
        )

        Self.colorContext.render(
            input.transformed(by: scale),
            toBitmap: &pixels,
            rowBytes: side * 4,
            bounds: CGRect(x: 0, y: 0, width: side, height: side),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var swatches: [Swatch] = []

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = UIColor(
                red: CGFloat(pixels[index]) / 255,
                green: CGFloat(pixels[index + 1]) / 255,
                blue: CGFloat(pixels[index + 2]) / 255,
                alpha: 1
            )

            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { continue }

            // Почти белое, почти чёрное и бесцветное акцентом быть не может.
            guard saturation > 0.25, brightness > 0.2, brightness < 0.95 else { continue }

            swatches.append(Swatch(hue: hue, saturation: saturation, brightness: brightness))
        }

        return swatches
    }

    /// Расстояние между оттенками на цветовом круге, 0...0.5.
    /// Круг замкнут, поэтому красный 0.99 и красный 0.01 — соседи, а не антиподы.
    nonisolated private static func hueDistance(_ one: CGFloat, _ other: CGFloat) -> CGFloat {
        let raw = abs(one - other)
        return min(raw, 1 - raw)
    }

    /// Акцент читается на любом фоне, поэтому насыщенность и яркость подтягиваются
    /// в рабочий диапазон — иначе бледная обложка дала бы почти невидимый цвет.
    nonisolated private static func color(from swatch: Swatch) -> UIColor {
        UIColor(
            hue: swatch.hue,
            saturation: min(max(swatch.saturation, 0.55), 0.9),
            brightness: min(max(swatch.brightness, 0.65), 0.95),
            alpha: 1
        )
    }

    nonisolated private static let colorContext = CIContext()
}
