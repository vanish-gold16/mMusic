import CoreImage
import UIKit

extension UIImage {
    /// Цвет, которым обложка «звучит»: не средний по всей картинке, а самый выразительный.
    ///
    /// Простое усреднение почти всегда даёт грязно-серый — яркое пятно тонет в фоне.
    /// Поэтому картинка сжимается в сетку, серые и почти чёрно-белые клетки выбрасываются,
    /// а из остальных берётся самая насыщенная.
    ///
    /// `nonisolated`, как и `averageBrightness`: интерфейс не трогает и должно
    /// считаться в фоновой задаче.
    nonisolated var dominantColor: UIColor? {
        guard let cgImage else { return nil }

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

        var best: (saturation: CGFloat, hue: CGFloat, brightness: CGFloat)?

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

            if best == nil || saturation > best!.saturation {
                best = (saturation, hue, brightness)
            }
        }

        guard let best else { return nil }

        // Акцент читается на любом фоне, поэтому насыщенность и яркость подтягиваются
        // в рабочий диапазон — иначе бледная обложка дала бы почти невидимый цвет.
        return UIColor(
            hue: best.hue,
            saturation: min(max(best.saturation, 0.55), 0.9),
            brightness: min(max(best.brightness, 0.65), 0.95),
            alpha: 1
        )
    }

    nonisolated private static let colorContext = CIContext()
}
