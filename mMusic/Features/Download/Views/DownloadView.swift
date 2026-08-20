import SwiftUI
import UniformTypeIdentifiers

struct DownloadView: View {
    @State private var isImporting = false
    /// Файлы, выбранные разом, ждут своей очереди: настройки заполняются по одному.
    @State private var pendingFiles: [PickedFile] = []
    @State private var currentFile: PickedFile?
    @State private var showSoundCloud = false
    /// Заполнено только для трека из SoundCloud — у обычного импорта теги читаются из файла.
    @State private var presetMetadata: AudioMetadata?
    
    var body: some View {
        VStack {
            VStack {
                HStack(spacing: 16) {
                    Button {
                        isImporting = true
                    } label: {
                        VStack {
                            Text("Upload music")
                            Image(systemName: "square.and.arrow.down")
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(.blue)
                    
                    Button {
                        
                    } label: {
                        VStack {
                            Text("From YouTube")
                            Image(systemName: "video")
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(.red)
                    
                }
                
                Button {
                    showSoundCloud = true
                } label: {
                    VStack {
                        Text("SoundCloud")
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 15))
                .padding(.top)
                .tint(.orange)
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true,
                onCompletion: handleFileLoading
            )
            .padding()

            Spacer()

            if !pendingFiles.isEmpty {
                Text("\(pendingFiles.count) more to go")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }
        .navigationTitle("Download")
        .sheet(item: $currentFile, onDismiss: showNextFile) { file in
            SettingView(file: file, preset: presetMetadata)
        }
        .sheet(isPresented: $showSoundCloud) {
            SoundCloudImportView { file, metadata in
                presetMetadata = metadata
                pendingFiles = [file]
                showNextFile()
            }
        }
    }
    
    private func handleFileLoading(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            presetMetadata = nil
            pendingFiles = urls.map { PickedFile(url: $0) }
            showNextFile()
        case .failure(let error):
            print(error)
        }
    }

    /// Следующий файл открывается не в тот же такт, что закрылся предыдущий лист:
    /// присвоенный прямо в `onDismiss` item новый sheet не показывает.
    private func showNextFile() {
        guard !pendingFiles.isEmpty else { return }

        let next = pendingFiles.removeFirst()
        Task { @MainActor in
            currentFile = next
        }
    }
}
