import SwiftUI

/// Шапка формы плейлиста — создания и правки: тот же веер обложек, что на
/// странице плейлиста, только главную карту здесь меняют нажатием. Под ним
/// имя крупным сжатым шрифтом, описание и паспорт.
///
/// Цвета передней обложки уходят наружу: ими форма светится и красит кнопки.
struct PlaylistFormHeader: View {

    @Binding var artworkData: Data?
    @Binding var name: String
    @Binding var description: String
    /// Из чего собирать веер, спереди назад: своя обложка, потом обложки треков.
    let fanSources: [Data]
    let passport: String
    @Binding var palette: CoverPalette?

    @State private var covers: [UIImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CoverEditMenu(artworkData: $artworkData) {
                CoverFan(covers: covers, size: 150)
            }

            VStack(alignment: .leading, spacing: 6) {
                RecordTitleField(placeholder: "Playlist name", text: $name)

                TextField("Add a description", text: $description, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1...4)

                RecordPassport(parts: [passport])
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .task(id: fanSources.map(\.count)) {
            await loadCovers()
        }
    }

    /// Главная карта веера здесь 150 pt — около 450 px на экране @3x.
    private func loadCovers() async {
        let sources = Array(fanSources.prefix(3))

        let (images, colors) = await Task.detached(priority: .utility) {
            let images = sources.compactMap { UIImage.thumbnail(from: $0, side: 480) }
            return (images, images.first?.coverPalette)
        }.value

        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            covers = images
            palette = colors
        }
    }
}
