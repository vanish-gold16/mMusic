import CoreImage
import SwiftUI
import UIKit

/// Цвета, которыми нарисована обложка. Не «подобранные под неё», а её собственные:
/// тёмная обложка даёт тёмный фон, блёклая — блёклый.
///
/// Единственное исключение — `accent`: им красятся кнопки и tint всего приложения,
/// поэтому совсем невидимый цвет подтягивается до различимого. Подтягивается только
/// вверх: яркая обложка отдаёт свой цвет как есть.
struct CoverPalette: Equatable, Sendable {

    /// Главный цвет обложки — тот, которого на ней больше всего. Им залит фон.
    let base: Color
    /// Второй по заметности цвет другого оттенка. Им фон «дышит» поверх первого.
    let secondary: Color
    /// Самый выразительный цвет: кнопки, волна, tint приложения.
    let accent: Color
    /// Фон из этих цветов светлый — значит, текст поверх него должен быть тёмным.
    let isLight: Bool
    /// Светлота основного цвета, 0...1. По ней решают, нужна ли фону вуаль:
    /// на почти чёрном белый текст читается и без неё.
    let baseLuminance: Double

    /// Пока ничего не играет и обложки нет.
    static let fallback = CoverPalette(
        base: Color(white: 0.12),
        secondary: Color(red: 0.35, green: 0.2, blue: 0.5),
        accent: .orange,
        isLight: false,
        baseLuminance: 0.12
    )
}

extension UIImage {

    /// Один цвет обложки: усреднённый по своей «корзине» и с долей площади,
    /// которую он занимает.
    private struct Swatch {
        let color: UIColor
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        /// Доля пикселей обложки, 0...1.
        let share: Double
    }

    /// Разбор обложки на палитру. `nonisolated`: интерфейс не трогает и должно
    /// считаться в фоновой задаче.
    nonisolated var coverPalette: CoverPalette? {
        let swatches = colorSwatches()
        guard !swatches.isEmpty else { return nil }

        // Почти чёрные и почти белые пятна не должны решать за всю обложку: иначе
        // тёмное фото даёт чёрный экран, хотя цвет на нём есть. Но если цветного
        // на обложке правда нет, берём то, что есть.
        let colourful = swatches.filter { $0.saturation > 0.18 && $0.brightness > 0.12 && $0.share > 0.08 }
        guard let base = (colourful + swatches).max(by: { left, right in
            Self.weight(left, amongColourful: !colourful.isEmpty) < Self.weight(right, amongColourful: !colourful.isEmpty)
        }) else { return nil }

        // Второй цвет должен читаться как другой: оттенок разводится минимум на 30°
        // (0.08 круга). Среди подходящих берётся не самый большой и не самый яркий,
        // а компромисс — иначе на фото победит серое небо.
        let secondary = swatches
            .filter { Self.hueDistance($0.hue, base.hue) > 0.08 }
            .max { left, right in
                left.share * (0.35 + left.saturation) < right.share * (0.35 + right.saturation)
            }

        // Акцент — самый выразительный цвет, но не одинокий пиксель: доля площади
        // входит в оценку корнем, чтобы крупное пятно перевешивало точку.
        let accent = swatches.max { left, right in
            Self.vividness(left) < Self.vividness(right)
        } ?? base

        let baseColor = Self.floored(base, minimumBrightness: 0.16)
        // Одноцветная обложка второго цвета не даёт — берём соседний по кругу:
        // противоположный смотрелся бы наклейкой, соседний — переливом.
        let secondaryColor = secondary.map { Self.floored($0, minimumBrightness: 0.28) }
            ?? Self.shifted(baseColor, byHue: 0.1)

        return CoverPalette(
            base: Color(baseColor),
            secondary: Color(secondaryColor),
            accent: Color(Self.legible(accent)),
            isLight: Self.isLight(base: baseColor, secondary: secondaryColor),
            baseLuminance: Self.luminance(baseColor)
        )
    }

    /// Обложка, сжатая до сетки 32×32 и схлопнутая в «корзины»: соседние оттенки
    /// одного пятна должны считаться одним цветом, а не полусотней разных.
    nonisolated private func colorSwatches() -> [Swatch] {
        guard let cgImage else { return [] }

        let side = 32
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

        /// Сумма цветов одной корзины: усреднять надо в RGB, иначе на границе
        /// красного оттенки 0.99 и 0.01 дадут в среднем зелёный.
        struct Bin {
            var count = 0
            var red = 0.0
            var green = 0.0
            var blue = 0.0
        }

        var bins: [Int: Bin] = [:]

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index]) / 255
            let green = Double(pixels[index + 1]) / 255
            let blue = Double(pixels[index + 2]) / 255

            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            let color = UIColor(red: red, green: green, blue: blue, alpha: 1)
            guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { continue }

            // Ключ корзины: 18 секторов оттенка, 3 ступени насыщенности, 4 яркости.
            // Бесцветные пиксели складываются в общие корзины по яркости — оттенок
            // у них случайный, разносить их по секторам бессмысленно.
            let hueBucket = saturation < 0.12 ? 0 : Int(hue * 18) + 1
            let key = hueBucket * 100 + Int(saturation * 3) * 10 + Int(brightness * 4)

            var bin = bins[key] ?? Bin()
            bin.count += 1
            bin.red += red
            bin.green += green
            bin.blue += blue
            bins[key] = bin
        }

        let total = Double(side * side)

        return bins.values.map { bin in
            let count = Double(bin.count)
            let color = UIColor(
                red: bin.red / count,
                green: bin.green / count,
                blue: bin.blue / count,
                alpha: 1
            )

            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            return Swatch(
                color: color,
                hue: hue,
                saturation: saturation,
                brightness: brightness,
                share: count / total
            )
        }
    }

    /// Кто займёт фон. Когда на обложке есть цветные пятна, бесцветные в счёт
    /// не идут — площадь сравнивается только между цветными.
    nonisolated private static func weight(_ swatch: Swatch, amongColourful: Bool) -> Double {
        guard amongColourful else { return swatch.share }

        let isColourful = swatch.saturation > 0.18 && swatch.brightness > 0.12 && swatch.share > 0.08
        return isColourful ? swatch.share : 0
    }

    /// Насколько цвет «звучит»: насыщенность в первую очередь, площадь — корнем,
    /// чтобы крупное пятно перевешивало точку, но не забивало её совсем.
    nonisolated private static func vividness(_ swatch: Swatch) -> Double {
        Double(swatch.saturation) * (0.35 + 0.65 * Double(swatch.brightness)) * swatch.share.squareRoot()
    }

    /// Расстояние между оттенками на цветовом круге, 0...0.5.
    /// Круг замкнут, поэтому красный 0.99 и красный 0.01 — соседи, а не антиподы.
    nonisolated private static func hueDistance(_ one: CGFloat, _ other: CGFloat) -> CGFloat {
        let raw = abs(one - other)
        return min(raw, 1 - raw)
    }

    /// Единственная поправка к цвету фона: не дать ему стать чернильной дырой,
    /// в которой не видно ни второго цвета, ни его дыхания. Оттенок и насыщенность
    /// остаются обложкины — поднимается только яркость, и только если она ниже порога.
    nonisolated private static func floored(_ swatch: Swatch, minimumBrightness: CGFloat) -> UIColor {
        guard swatch.brightness < minimumBrightness else { return swatch.color }

        return UIColor(hue: swatch.hue, saturation: swatch.saturation, brightness: minimumBrightness, alpha: 1)
    }

    /// Акцент виден и на светлом, и на тёмном интерфейсе. Поднимаем только то,
    /// что ниже порога: яркая обложка отдаёт свой цвет нетронутым.
    nonisolated private static func legible(_ swatch: Swatch) -> UIColor {
        UIColor(
            hue: swatch.hue,
            saturation: max(swatch.saturation, 0.45),
            brightness: min(max(swatch.brightness, 0.6), 0.95),
            alpha: 1
        )
    }

    nonisolated private static func shifted(_ color: UIColor, byHue delta: CGFloat) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return UIColor(
            hue: (hue + delta).truncatingRemainder(dividingBy: 1),
            saturation: saturation,
            brightness: brightness,
            alpha: 1
        )
    }

    /// Светлота будущего фона: основной цвет решает почти всё, второй подмешивается.
    /// Веса неравные: глаз сильнее всего реагирует на зелёный, слабее всего на синий.
    nonisolated private static func isLight(base: UIColor, secondary: UIColor) -> Bool {
        0.8 * luminance(base) + 0.2 * luminance(secondary) > 0.55
    }

    nonisolated private static func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    nonisolated private static let colorContext = CIContext()
}
