import SwiftUI

/// Разделитель, как в ящике с пластинками: крупная сжатая метка, черта по её
/// базовой линии до края и мелкая подпись в конце. Стоит между группами
/// альбомов в библиотеке и между сторонами пластинки на странице альбома.
struct CrateDivider: View {

    let title: String
    /// Число альбомов за разделителем, длина стороны — что уместно.
    var detail: String = ""
    var size: CGFloat = 30

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: size, weight: .heavy).width(.compressed))

            // У фигуры нет базовой линии текста, и по ней выравнивается её низ —
            // черта ложится ровно под буквы.
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)

            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
