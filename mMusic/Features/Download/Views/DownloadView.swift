import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Окно импорта: откуда взять музыку и что из взятого уже легло в библиотеку.
///
/// Источников два. Файлы — пунктирный слот, как «Add music» в плейлисте:
/// это пустое место, куда музыку кладут. SoundCloud — строка для ссылки прямо
/// здесь, без отдельного листа. Пустой кнопки «From YouTube» больше нет:
/// она ничего не делала.
///
/// Каждый файл дальше проходит через форму `SettingView`, по одному. Между
/// формами здесь видно, сколько файлов ещё ждёт и какие треки уже добавлены, —
/// их можно сразу послушать или поправить.
struct DownloadView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    /// Файлы, выбранные разом, ждут своей очереди: настройки заполняются по одному.
    @State private var pendingFiles: [PickedFile] = []
    @State private var currentFile: PickedFile?
    /// Следующая форма уже назначена, но ещё не показана (см. `showNextFile`).
    /// Без флага два файла, пришедшие в этот промежуток, открыли бы две формы
    /// разом, и одна затёрла бы другую.
    @State private var isOpeningNext = false
    @State private var isDownloading = false
    /// Треки, добавленные за этот заход, — свежие сверху.
    @State private var added: [Track] = []
    /// Для «2 OF 5» в форме: сколько файлов в текущей пачке и какой из них открыт.
    @State private var batchTotal = 0
    @State private var batchIndex = 0
    /// Цвета обложки последнего добавленного трека: окно светится тем,
    /// что в него только что легло. Пока ничего не добавлено — фон обычный.
    @State private var palette: CoverPalette?

    /// Трек могли удалить прямо из этого списка — меню строки это умеет.
    /// Удалённую модель трогать нельзя, поэтому её здесь уже нет.
    private var visibleAdded: [Track] {
        added.filter { !$0.isDeleted && $0.modelContext != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                filesSlot
                soundCloud

                if !pendingFiles.isEmpty {
                    queue
                }

                if !visibleAdded.isEmpty {
                    justAdded
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            .animation(.snappy, value: pendingFiles.count)
            .animation(.snappy, value: added.count)
        }
        .scrollDismissesKeyboard(.interactively)
        .containerBackground(for: .navigation) {
            CoverAura(palette: palette, breathes: false)
        }
        // В цвет последнего добавленного — до `.toolbar` и листов, как везде.
        .tint(palette?.accent)
        .task(id: visibleAdded.first?.id) {
            await loadPalette()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("done") { dismiss() }
                    .disabled(isDownloading)
            }
        }
        .interactiveDismissDisabled(isDownloading)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true,
            onCompletion: handleFileLoading
        )
        .sheet(item: $currentFile, onDismiss: showNextFile) { file in
            SettingView(file: file, step: stepLabel) { track in
                added.insert(track, at: 0)
            }
        }
    }

    // MARK: - Источники

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Import")
                .font(.system(size: 44, weight: .heavy).width(.compressed))

            Text(summary)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var summary: String {
        let count = visibleAdded.count
        guard count > 0 else { return "ADD MUSIC TO THE LIBRARY" }

        return (count == 1 ? "1 track added" : "\(count) tracks added").uppercased()
    }

    /// Пустое место, куда кладут файлы. Пунктир — тот же, что у «Add music»
    /// и «New playlist»: по всему приложению так выглядит «сюда можно положить».
    private var filesSlot: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return Button {
            isImporting = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 56, height: 56)
                    .background(.tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("From Files")
                        .font(.system(size: 28, weight: .heavy).width(.compressed))
                        .foregroundStyle(Color.primary)

                    Text("ANY AUDIO  ·  SEVERAL AT ONCE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 116)
            .background {
                shape.strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var soundCloud: some View {
        VStack(alignment: .leading, spacing: 12) {
            CrateDivider(title: "SOUNDCLOUD", detail: "BY LINK", size: 22)
                .padding(.horizontal)

            SoundCloudLinkField(isWorking: $isDownloading) { file in
                enqueue([file])
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Очередь и добавленное

    /// Файлы, которые ждут своей формы, — номерами, как трек-лист на конверте.
    private var queue: some View {
        VStack(alignment: .leading, spacing: 12) {
            CrateDivider(
                title: "UP NEXT",
                detail: pendingFiles.count == 1 ? "1 FILE" : "\(pendingFiles.count) FILES",
                size: 22
            )

            ForEach(Array(pendingFiles.enumerated()), id: \.element.id) { index, file in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)

                    Text(file.preset?.title ?? file.url.deletingPathExtension().lastPathComponent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal)
    }

    /// Только что добавленные — обычными строками трека: их можно сразу
    /// послушать или поправить опечатку, не уходя из импорта.
    private var justAdded: some View {
        let tracks = visibleAdded

        return VStack(alignment: .leading, spacing: 12) {
            CrateDivider(title: "JUST ADDED", detail: "\(tracks.count)", size: 22)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(tracks) { track in
                    TrackCell(track: track, queue: tracks, leadingStyle: .artwork, showDuration: true)
                }
            }
        }
    }

    // MARK: - Ход импорта

    private func loadPalette() async {
        let data = visibleAdded.first?.displayArtwork

        let colors = await Task.detached(priority: .utility) {
            data.flatMap { UIImage.thumbnail(from: $0, side: 200) }?.coverPalette
        }.value

        guard !Task.isCancelled else { return }
        palette = colors
    }

    private var stepLabel: String? {
        batchTotal > 1 ? "\(batchIndex) OF \(batchTotal)" : nil
    }

    private func handleFileLoading(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            enqueue(urls.map { PickedFile(url: $0) })
        case .failure(let error):
            print(error)
        }
    }

    /// Новые файлы встают в конец очереди. Форма открывается сразу, только если
    /// сейчас никакая не открыта, — иначе следующую откроет закрытие текущей.
    private func enqueue(_ files: [PickedFile]) {
        guard !files.isEmpty else { return }

        let isIdle = currentFile == nil && !isOpeningNext

        if isIdle, pendingFiles.isEmpty {
            batchTotal = 0
            batchIndex = 0
        }

        pendingFiles.append(contentsOf: files)
        batchTotal += files.count

        if isIdle {
            showNextFile()
        }
    }

    /// Следующий файл открывается не в тот же такт, что закрылся предыдущий лист:
    /// присвоенный прямо в `onDismiss` item новый sheet не показывает.
    private func showNextFile() {
        guard !pendingFiles.isEmpty else { return }

        let next = pendingFiles.removeFirst()
        batchIndex += 1
        isOpeningNext = true

        Task { @MainActor in
            currentFile = next
            isOpeningNext = false
        }
    }
}
