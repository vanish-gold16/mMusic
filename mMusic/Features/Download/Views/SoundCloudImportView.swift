import SwiftUI

/// Лист SoundCloud для редакторов альбома: там своя форма трека, и окно импорта
/// целиком ни к чему — нужна только строка для ссылки. В самом окне импорта
/// та же строка стоит прямо на месте, без листа.
struct SoundCloudImportView: View {

    let onReady: (PickedFile, AudioMetadata) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("SoundCloud")
                    .font(.system(size: 40, weight: .heavy).width(.compressed))
                    .padding(.horizontal)

                SoundCloudLinkField(isWorking: $isWorking) { file in
                    onReady(file, file.preset ?? AudioMetadata())
                    dismiss()
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 8)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isWorking)
    }
}
