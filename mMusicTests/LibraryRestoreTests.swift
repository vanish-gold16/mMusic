import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на восстановление библиотеки по файлам: ровно тот случай, когда записи
/// о треках потеряны, а сами файлы в Documents на месте.
@MainActor
struct LibraryRestoreTests {

    private let container: ModelContainer
    /// Свои имена файлов на каждый прогон: тесты пишут в настоящий Documents
    /// приложения-хоста, и мусор от соседнего теста здесь ни к чему.
    private let suffix = UUID().uuidString.prefix(8)

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Уникальная часть добавляется в конец имени, а не в начало: разбор
    /// «артист — название» смотрит на первый разделитель, и префикс приклеился бы
    /// к имени артиста.
    private func makeFile(_ name: String) -> String {
        let url = URL(fileURLWithPath: name)
        let filename = "\(url.deletingPathExtension().lastPathComponent) \(suffix).\(url.pathExtension)"
        FileManager.default.createFile(atPath: AudioFileStore.url(for: filename).path, contents: Data([0, 1, 2, 3]))
        return filename
    }

    private func cleanUp(_ filenames: [String]) {
        filenames.forEach { AudioFileStore.remove(filename: $0) }
    }

    /// Трек с историей возвращается с прежним названием, артистами, жанром,
    /// счётчиком прослушиваний и своим альбомом.
    @Test func restoresFromPlayHistory() async throws {
        let context = container.mainContext
        let filename = makeFile("history.mp3")
        defer { cleanUp([filename]) }

        // Как было до потери: трек в альбоме, с артистом и двумя прослушиваниями.
        let album = Album(name: "Night Album", type: .LP)
        context.insert(album)

        let lost = Track(name: "Real Name", credits: [], genre: .rock, filename: filename)
        context.insert(lost)
        lost.album = album
        let artist = context.findOrCreateArtist(named: "Vera Sound")
        context.insert(Credit(artist: artist, role: .main, position: 0, track: lost))

        let older = PlayEvent(track: lost, seconds: 120)
        older.playedAt = .now.addingTimeInterval(-86_400)
        let newer = PlayEvent(track: lost, seconds: 200)
        context.insert(older)
        context.insert(newer)

        // Катастрофа: запись о треке исчезла, файл остался.
        context.delete(lost)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Track>()).isEmpty)

        let result = await LibraryRestore.restore([filename], in: context)
        #expect(result.restored == 1)
        #expect(result.fromHistory == 1)

        let restored = try #require(try context.fetch(FetchDescriptor<Track>()).first)
        #expect(restored.name == "Real Name")
        #expect(restored.genre == .rock)
        #expect(restored.artistNames == ["Vera Sound"])
        #expect(restored.playCount == 2)
        #expect(restored.album?.name == "Night Album")
        #expect(restored.lastPlayedAt == newer.playedAt)
    }

    /// Без истории трек собирается из имени файла — «артист — название».
    @Test func restoresFromFilenameWhenThereIsNoHistory() async throws {
        let context = container.mainContext
        let filename = makeFile("Vera Sound — Nightfall.mp3")
        defer { cleanUp([filename]) }

        let result = await LibraryRestore.restore([filename], in: context)
        #expect(result.restored == 1)
        #expect(result.fromHistory == 0)

        let restored = try #require(try context.fetch(FetchDescriptor<Track>()).first)
        #expect(restored.name == "Nightfall \(suffix)")
        #expect(restored.artistNames == ["Vera Sound"])
        #expect(restored.playCount == 0)
    }

    /// Файлы, на которые уже ссылается трек, восстанавливать нечего.
    @Test func orphansSkipKnownFiles() throws {
        let context = container.mainContext
        let known = makeFile("known.mp3")
        let orphan = makeFile("orphan.mp3")
        defer { cleanUp([known, orphan]) }

        let track = Track(name: "Known", credits: [], genre: .pop, filename: known)
        context.insert(track)

        let found = LibraryRestore.orphanFiles(known: [known])
        #expect(found.contains(orphan))
        #expect(!found.contains(known))
    }
}
