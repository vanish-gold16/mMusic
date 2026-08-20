import SwiftUI

/// Подпись раздела: мелкая и приглушённая, а не крупная и жирная.
/// Крупный жирный заголовок над лентой — самый узнаваемый приём Apple Music;
/// здесь главным должен быть контент, а подпись только помечает его.
struct SectionLabel: View {

    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }
}
