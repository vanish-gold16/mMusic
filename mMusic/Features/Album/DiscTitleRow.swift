import SwiftUI

/// Начало пластинки в редакторе альбома: номер и поле для названия.
///
/// В списке треков это граница: всё, что ниже неё (до следующей), лежит на
/// этой пластинке. Её перетаскивают, как трек, — так альбом и делят на пластинки.
struct DiscTitleRow: View {

    let number: Int
    @Binding var title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "record.circle")
                .foregroundStyle(.secondary)

            Text("DISC \(number)")
                .font(.system(size: 20, weight: .heavy).width(.compressed))

            TextField("Title", text: $title)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
