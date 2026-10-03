import SwiftUI

/// Строка «вставь ссылку — получи файл»: поле в стеклянной капсуле, вставка
/// из буфера и кнопка загрузки. Стоит прямо в окне импорта — ради одного поля
/// открывать ещё один лист незачем — и в листе SoundCloud у редакторов альбома.
///
/// Готовый файл уходит наружу вместе с метаданными SoundCloud — дальше его
/// правит обычная форма импорта.
struct SoundCloudLinkField: View {

    /// Загрузка идёт. Наружу — чтобы лист нельзя было смахнуть посреди неё.
    @Binding var isWorking: Bool
    let onReady: (PickedFile) -> Void

    @State private var link = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        link.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TextField("soundcloud.com/…", text: $link)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(start)
                    .focused($isFocused)
                    .disabled(isWorking)
                    .padding(.leading, 18)

                trailingButton
            }
            .frame(minHeight: 52)
            .padding(.trailing, 6)
            .glassEffect()

            // Одна строка под полем: ошибка, ход загрузки или подсказка —
            // смотря что сейчас важнее.
            Group {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else if isWorking {
                    Text("Downloading…".uppercased())
                        .foregroundStyle(.secondary)
                } else {
                    Text("One track — not a profile or a playlist".uppercased())
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.2)
            .padding(.horizontal, 18)
        }
    }

    /// Пустое поле — кнопка вставки, заполненное — кнопка загрузки:
    /// нужна всегда ровно одна из них.
    @ViewBuilder
    private var trailingButton: some View {
        if isWorking {
            ProgressView()
                .frame(width: 40, height: 40)
        } else if trimmed.isEmpty {
            Button {
                paste()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("Paste")
        } else {
            Button(action: start) {
                Image(systemName: "arrow.down")
                    .font(.body.weight(.bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Download")
        }
    }

    /// Вставленная ссылка на SoundCloud сразу и скачивается: ради неё её и вставляли.
    private func paste() {
        guard let pasted = UIPasteboard.general.string else { return }

        link = pasted
        if pasted.localizedCaseInsensitiveContains("soundcloud") {
            start()
        }
    }

    private func start() {
        guard !trimmed.isEmpty, !isWorking else { return }
        Task { await download() }
    }

    private func download() async {
        isFocused = false
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let track = try await SoundCloudClient.resolve(trimmed)
            let file = try await SoundCloudClient.download(track)
            let artwork = await SoundCloudClient.artworkData(for: track)

            let metadata = AudioMetadata(
                title: track.title,
                artist: track.artist,
                albumName: nil,
                artwork: artwork
            )

            link = ""
            onReady(PickedFile(url: file, preset: metadata))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
