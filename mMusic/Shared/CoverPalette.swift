import CoreImage
import SwiftUI
import UIKit

/// Цвета, которыми нарисована обложка. Не «подобранные под неё», а её собственные:
/// тёмная обложка даёт тёмный фон, блёклая — блёклый.
///
/// Исключения — два цвета для кнопок, `accent` и `onBase`: кнопка должна быть
/// видна, поэтому их цвет подтягивается до различимого. Только вверх: яркая
/// обложка отдаёт свой цвет как есть.
struct CoverPalette: Equatable, Sendable {

    /// Главный цвет обложки — тот, которого на ней больше всего. Им залит фон.
    let base: Color
    /// Второй по заметности цвет другого оттенка. Им фон «дышит» поверх первого.
    let secondary: Color
    /// Tint приложения: тот же главный цвет, доведённый до читаемого на фоне
    /// экрана — в тёмной теме он светлее, в светлой темнее. Раньше здесь
    /// был самый яркий цвет обложки, и маленький кислотный логотип на тёмном
    /// конверте красил собой всё приложение.
    let accent: Color
    /// Цвет кнопок поверх `base` — в плеере и на всём, что открыто из него.
    /// Там `accent` того же оттенка, что и фон, слился бы с ним, поэтому берётся
    /// самый выразительный цвет обложки, который на этом фоне различим. Если
    /// такого нет — например, обложка вся одного цвета, — цвет текста.
    let onBase: Color
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
        onBase: .orange,
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
        let colourful = swatches.filter { Self.isColourful($0) && $0.share > 0.08 }
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

        // Самые выразительные цвета по убыванию, но не одинокие пиксели: доля
        // площади входит в оценку корнем, чтобы крупное пятно перевешивало точку.
        // Серые не в счёт: подтянутая до «различимой» насыщенность выдумала бы
        // им цвет, которого на обложке нет.
        let vivid = swatches
            .filter { Self.isColourful($0) && $0.share > 0.01 }
            .sorted { Self.vividness($0) > Self.vividness($1) }

        let baseColor = Self.floored(base, minimumBrightness: 0.16)
        // Одноцветная обложка второго цвета не даёт — берём соседний по кругу:
        // противоположный смотрелся бы наклейкой, соседний — переливом.
        let secondaryColor = secondary.map { Self.floored($0, minimumBrightness: 0.28) }
            ?? Self.shifted(baseColor, byHue: 0.1)
        let isLight = Self.isLight(base: baseColor, secondary: secondaryColor)

        // Tint — главный цвет. Если он серый (чёрно-белое фото с красной
        // надписью), оттенок даёт самое яркое пятно; совсем бесцветной обложке
        // остаётся цвет приложения.
        let accent: UIColor
        if Self.isColourful(base) {
            accent = Self.legible(base)
        } else if let brightest = vivid.first {
            accent = Self.legible(brightest)
        } else {
            accent = UIColor(Color.orange)
        }

        // Поверх главного цвета — первый выразительный, который на нём читается.
        // 3:1 — порог WCAG для значков и линий: текстом эти цвета не бывают.
        let text: UIColor = isLight ? .black : .white
        let onBase = vivid
            .lazy
            .map { Self.legible($0) }
            .first { Self.contrast($0, baseColor) >= 3 }
            ?? text

        return CoverPalette(
            base: Color(baseColor),
            secondary: Color(secondaryColor),
            accent: Color(Self.readable(accent)),
            onBase: Color(onBase),
            isLight: isLight,
            baseLuminance: Self.luminance(baseColor)
        )
    }

    /// Пятно — цвет, а не серое и не почти чёрное: у тех оттенок случайный.
    nonisolated private static func isColourful(_ swatch: Swatch) -> Bool {
        swatch.saturation > 0.18 && swatch.brightness > 0.12
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

        return isColourful(swatch) && swatch.share > 0.08 ? swatch.share : 0
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

    /// Tint лежит на обычном фоне экрана — чёрном в тёмной теме, белом в светлой.
    /// Синий с той же яркостью по HSB, что и оранжевый, на чёрном почти не виден,
    /// а жёлтый не виден на белом, поэтому цвет подстраивается под тему: в тёмной
    /// светлеет, в светлой темнеет, пока не наберёт контраст 3.5:1. Оттенок
    /// остаётся обложкиным, меняется только светлота.
    nonisolated private static func readable(_ color: UIColor) -> UIColor {
        let onDark = reaching(3.5, from: color, against: .black, mixing: .white)
        let onLight = reaching(3.5, from: color, against: .white, mixing: .black)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? onDark : onLight
        }
    }

    /// Подмешивает `mixing` шагами по 5%, пока контраст с фоном не дойдёт до нужного.
    nonisolated private static func reaching(
        _ target: Double,
        from color: UIColor,
        against background: UIColor,
        mixing other: UIColor
    ) -> UIColor {
        var from = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))
        var to = from
        color.getRed(&from.red, green: &from.green, blue: &from.blue, alpha: &from.alpha)
        other.getRed(&to.red, green: &to.green, blue: &to.blue, alpha: &to.alpha)

        var result = color
        var amount: CGFloat = 0
        while contrast(result, background) < target, amount < 1 {
            amount = min(amount + 0.05, 1)
            result = UIColor(
                red: from.red + (to.red - from.red) * amount,
                green: from.green + (to.green - from.green) * amount,
                blue: from.blue + (to.blue - from.blue) * amount,
                alpha: 1
            )
        }
        return result
    }

    /// Контраст двух цветов по WCAG: 1 — неразличимы, 21 — чёрный на белом.
    /// Светлота здесь честная, с линеаризацией sRGB: `luminance` ниже — быстрая
    /// оценка «светлый или тёмный», для порогов контраста она врёт.
    nonisolated private static func contrast(_ one: UIColor, _ other: UIColor) -> Double {
        let first = relativeLuminance(one)
        let second = relativeLuminance(other)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    nonisolated private static func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ channel: CGFloat) -> Double {
            let value = Double(min(max(channel, 0), 1))
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    nonisolated private static func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.299 * red + 0.587 * green + 0.114 * blue
    }

    nonisolated private static let colorContext = CIContext()
}
