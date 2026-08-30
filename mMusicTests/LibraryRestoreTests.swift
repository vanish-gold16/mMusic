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

    /// Трек, оставшийся без альбома, возвращается в него по истории. Название берётся
    /// из самого свежего события, где оно записано: в старых его может не быть —
    /// трек тогда ещё не лежал в альбоме.
    @Test func linksAlbumsForTracksThatLostThem() async throws {
        let context = container.mainContext
        let filename = makeFile("lost-album.mp3")
        defer { cleanUp([filename]) }

        let album = Album(name: "Night Album", type: .LP)
        context.insert(album)

        let source = Track(name: "Song", credits: [], genre: .pop, filename: filename)
        context.insert(source)

        let early = PlayEvent(track: source, seconds: 60)
        early.playedAt = .now.addingTimeInterval(-86_400)
        early.albumName = nil
        context.insert(early)

        source.album = album
        let late = PlayEvent(track: source, seconds: 60)
        context.insert(late)

        // Связь потерялась, альбом на месте.
        source.album = nil
        try context.save()

        let report = await LibraryRestore.linkMissingAlbums(in: context)
        #expect(report.linked == 1)
        #expect(source.album?.name == "Night Album")
    }

    /// Вернувшийся трек встаёт первым номером, а не вторым: на экране альбома
    /// номер — это `position + 1`, и лишняя единица здесь показывала «2» у
    /// единственного трека.
    @Test func linkedTracksAreNumberedFromTheStart() async throws {
        let context = container.mainContext
        let names = ["first.mp3", "second.mp3"]
        let filenames = names.map { makeFile($0) }
        defer { cleanUp(filenames) }

        let album = Album(name: "Night Album", type: .LP)
        context.insert(album)

        for filename in filenames {
            let track = Track(name: filename, credits: [], genre: .pop, filename: filename)
            context.insert(track)

            let event = PlayEvent(track: track, seconds: 60)
            event.albumName = "Night Album"
            context.insert(event)
        }
        try context.save()

        let report = await LibraryRestore.linkMissingAlbums(in: context)
        #expect(report.linked == 2)

        let positions = album.tracks.map(\.position).sorted()
        #expect(positions == [0, 1])
    }

    /// Трек, который уже лежит в альбоме, проход не трогает.
    @Test func linkingLeavesTracksThatAlreadyHaveAnAlbum() async throws {
        let context = container.mainContext
        let filename = makeFile("has-album.mp3")
        defer { cleanUp([filename]) }

        let right = Album(name: "Right", type: .LP)
        let wrong = Album(name: "Wrong", type: .LP)
        context.insert(right)
        context.insert(wrong)

        let track = Track(name: "Song", credits: [], genre: .pop, filename: filename)
        context.insert(track)
        track.album = right

        let event = PlayEvent(track: track, seconds: 60)
        event.albumName = "Wrong"
        context.insert(event)
        try context.save()

        let report = await LibraryRestore.linkMissingAlbums(in: context)
        #expect(report.linked == 0)
        #expect(track.album?.name == "Right")
    }

    /// Альбом известен по истории, но самого альбома в библиотеке уже нет —
    /// например, его убрала чистка пустых. Проход честно об этом сообщает,
    /// а по отдельной просьбе собирает альбом заново.
    @Test func reportsAndRecreatesAlbumsThatAreGone() async throws {
        let context = container.mainContext
        let filename = makeFile("gone-album.mp3")
        defer { cleanUp([filename]) }

        let album = Album(name: "Gone Album", type: .LP)
        context.insert(album)

        let track = Track(name: "Song", credits: [], genre: .pop, filename: filename)
        context.insert(track)
        track.album = album
        context.insert(PlayEvent(track: track, seconds: 60))

        // Альбом исчез, трек остался без него.
        track.album = nil
        context.delete(album)
        try context.save()

        let report = await LibraryRestore.linkMissingAlbums(in: context)
        #expect(report.linked == 0)
        #expect(report.missingAlbums == ["Gone Album"])
        #expect(report.withoutName == 0)

        let recreated = await LibraryRestore.linkMissingAlbums(in: context, recreatingMissing: true)
        #expect(recreated.linked == 1)
        #expect(track.album?.name == "Gone Album")
    }

    /// Ни истории, ни тега — восстановить неоткуда, и это должно быть видно.
    @Test func reportsTracksWithNoAlbumNameAnywhere() async throws {
        let context = container.mainContext
        let filename = makeFile("no-clue.mp3")
        defer { cleanUp([filename]) }

        let track = Track(name: "Song", credits: [], genre: .pop, filename: filename)
        context.insert(track)
        try context.save()

        let report = await LibraryRestore.linkMissingAlbums(in: context)
        #expect(report.linked == 0)
        #expect(report.withoutName == 1)
        #expect(track.album == nil)
    }

    /// Регистр и лишние пробелы в теге не должны мешать найти альбом.
    @Test func matchesAlbumNameIgnoringCaseAndSpaces() async throws {
        let context = container.mainContext
        let filename = makeFile("case.mp3")
        defer { cleanUp([filename]) }

        let album = Album(name: "Night Album", type: .LP)
        context.insert(album)

        let track = Track(name: "Song", credits: [], genre: .pop, filename: filename)
        context.insert(track)

        let event = PlayEvent(track: track, seconds: 60)
        event.albumName = "  night album "
        context.insert(event)
        try context.save()

        let report = await LibraryRestore.linkMissingAlbums(in: context)
        #expect(report.linked == 1)
        #expect(track.album?.name == "Night Album")
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
