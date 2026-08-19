import Foundation

/// Единственное место, где приложение трогает аудиофайлы в Documents.
/// `Track.filename` — это имя файла внутри этой папки, и его уникальность держится здесь:
/// раньше каждый экран импорта решал вопрос сам, а `SettingView` не решал вовсе —
/// второй импорт файла с тем же именем молча создавал трек, указывающий на чужой mp3.
enum AudioFileStore {

    enum StoreError: LocalizedError {
        case transferFailed(name: String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .transferFailed(let name, let underlying):
                return "Не удалось сохранить «\(name)»: \(underlying.localizedDescription)"
            }
        }
    }

    /// Путь к файлу трека по его `filename`.
    static func url(for filename: String) -> URL {
        URL.documentsDirectory.appending(path: filename)
    }

    /// Копирует файл из-за пределов песочницы (то, что вернул `fileImporter`) в Documents.
    /// Возвращает имя, под которым файл там лёг, — именно оно пишется в `Track.filename`.
    static func importFile(from source: URL) throws -> String {
        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }

        return try place(source, using: FileManager.default.copyItem(at:to:))
    }

    /// Переносит в Documents файл, уже подготовленный во временной папке.
    /// Именно перенос, а не копия: временная копия после этого не нужна.
    static func moveIntoLibrary(from staged: URL) throws -> String {
        try place(staged, using: FileManager.default.moveItem(at:to:))
    }

    /// Удаляет файл трека. Отсутствие файла — не ошибка: строка в базе вполне могла его пережить.
    static func remove(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// Общая часть копирования и переноса: подобрать свободное имя и выполнить саму операцию.
    /// `transfer` — это `copyItem` или `moveItem`; различаются они только этим.
    private static func place(_ source: URL, using transfer: (URL, URL) throws -> Void) throws -> String {
        let destination = uniqueDestination(for: source.lastPathComponent)

        do {
            try transfer(source, destination)
        } catch {
            throw StoreError.transferFailed(name: source.lastPathComponent, underlying: error)
        }

        return destination.lastPathComponent
    }

    /// Имя остаётся человекочитаемым, а при совпадении получает суффикс.
    /// Цикл, а не одна попытка: свободное имя нужно гарантированно, а не почти наверняка.
    private static func uniqueDestination(for filename: String) -> URL {
        let candidate = URL.documentsDirectory.appending(path: filename)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = candidate.deletingPathExtension().lastPathComponent
        let fileExtension = candidate.pathExtension

        while true {
            let unique = URL.documentsDirectory
                .appending(path: base + "-" + UUID().uuidString)
                .appendingPathExtension(fileExtension)

            if !FileManager.default.fileExists(atPath: unique.path) { return unique }
        }
    }
}
