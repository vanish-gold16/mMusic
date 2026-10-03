import SwiftUI

/// Капсула артиста в редакторе авторов. Стеклянная, как строки треков и кнопки
/// по всему приложению; авторы альбома, которых здесь не правят, приглушены.
///
/// Звезда — роль: залитая у основного автора, контурная у гостя. Залитая
/// красится акцентом, чтобы основных было видно с первого взгляда.
struct TrackArtistCell: View {

    var name: String
    var role: CreditRole = .main

    var showDelete: Bool
    var showRole: Bool
    var editable: Bool

    var onTap: () -> Void = {}
    var onRemove: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            if showRole {
                Image(systemName: role == .main ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(role == .main ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(role == .main ? "Main artist" : "Guest")
            }

            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(editable ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))

            if showDelete {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(name)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        // Автор альбома — прозрачное стекло: его видно, но правят его не здесь.
        .glassEffect(editable ? .regular : .clear, in: Capsule())
        .fixedSize()
        .contentShape(Capsule())
        .onTapGesture(perform: onTap)
    }
}
