import Foundation
import SwiftData
import Testing
@testable import mMusic

/// Тесты на жанр альбома. Своего жанра у альбома нет — это сводка по трекам,
/// а «поставить жанр альбому» значит переписать жанр каждого трека. Ошибка
/// здесь тихо портит библиотеку: жанр уезжает не туда или форма врёт, что он
/// один, когда треки уже разные.
@MainActor
struct AlbumGenreTests {

    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Track.self, Album.self, Artist.self, Credit.self,
            Playlist.self, TrackPlaylistItem.self, PlayEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// Альбом с треками заданных жанров, по порядку.
    private func makeAlbum(_ genres: [Genre], name: String = "Night Drive", type: Album.AlbumType = .LP) -> (Album, [Track]) {
        let album = Album(name: name, type: type)
        context.insert(album)

        let tracks = genres.enumerated().map { index, genre -> Track in
            let track = Track(name: "\(name) \(index)", credits: [], genre: genre, filename: "\(name)-\(index).mp3")
            context.insert(track)
            track.album = album
            track.position = index
            return track
        }

        return (album, tracks)
    }

    private func draft(_ genre: Genre) -> TrackDraft {
        TrackDraft(name: "Draft", genre: genre, stagedURL: URL(filePath: "/tmp/draft.mp3"))
    }

    // MARK: - Сводка

    @Test func oneGenreOnEveryTrackIsTheAlbumGenre() {
        let genre = AlbumGenre([.rock, .rock, .rock])

        #expect(genre.common == .rock)
        #expect(!genre.isMixed)
        #expect(genre.trackCount == 3)
    }

    /// Разные жанры — не один из них, а «Mixed»: форма не должна выдавать
    /// самый частый жанр за жанр всего альбома.
    @Test func differentGenresAreMixed() {
        let genre = AlbumGenre([.rap, .rock, .rap, .indie])

        #expect(genre.common == nil)
        #expect(genre.isMixed)
        // Самый частый первым, остальные по алфавиту — как на странице альбома.
        #expect(genre.genres == [.rap, .indie, .rock])
    }

    /// Без треков жанра нет вовсе — ни одного, ни «разных».
    @Test func noTracksMeansNoGenre() {
        let genre = AlbumGenre([])

        #expect(genre.common == nil)
        #expect(!genre.isMixed)
        #expect(genre.trackCount == 0)
    }

    /// Файл, пришедший в альбом с одним жанром, берёт этот жанр; в альбом
    /// с разными жанрами или в пустой — прежний «Pop».
    @Test func aNewTrackTakesTheGenreOnlyWhenItIsShared() {
        #expect(AlbumGenre([.metal, .metal]).forNewTrack == .metal)
        #expect(AlbumGenre([.metal, .jazz]).forNewTrack == .pop)
        #expect(AlbumGenre([]).forNewTrack == .pop)
    }

    // MARK: - Альбом в базе

    @Test func settingTheAlbumGenreSetsEveryTrack() {
        let (album, tracks) = makeAlbum([.pop, .rap, .indie])

        album.setGenre(.rock)

        #expect(tracks.map(\.genre) == [.rock, .rock, .rock])
        #expect(album.tracksGenre.common == .rock)
    }

    /// Трек, у которого жанр уже нужный, не переписывается: каждая запись
    /// в базу будит все `@Query` приложения.
    @Test func tracksAlreadyInTheGenreAreLeftAlone() {
        let (album, _) = makeAlbum([.rock, .pop, .rock])

        #expect(album.setGenre(.rock) == 1)
        #expect(album.setGenre(.rock) == 0)
    }

    /// Главное обещание: жанр альбома не держит треки. Поменяли один — он
    /// поменялся один, а форма честно показывает разные жанры.
    @Test func aTrackChangedAfterwardsMakesTheAlbumMixed() {
        let (album, tracks) = makeAlbum([.pop, .pop, .pop])
        album.setGenre(.rock)

        tracks[1].genre = .jazz

        #expect(tracks.map(\.genre) == [.rock, .jazz, .rock])
        #expect(album.tracksGenre.isMixed)
        #expect(album.tracksGenre.genres == [.rock, .jazz])

        // А вернули — альбом снова одного жанра.
        tracks[1].genre = .rock
        #expect(album.tracksGenre.common == .rock)
    }

    /// Песня, которую сингл только показывает, живёт в другом альбоме: её
    /// жанр — дело того альбома. Жанр сингла её не трогает и не учитывает.
    @Test func aSongTheSingleOnlyShowsKeepsItsGenre() {
        let (album, albumTracks) = makeAlbum([.rap, .rap], name: "Big Album")
        let (single, singleTracks) = makeAlbum([.pop], name: "Single", type: .single)
        let shown = albumTracks[0]
        shown.single = single

        #expect(single.tracklist.count == 2)
        #expect(single.tracksGenre.common == .pop)

        single.setGenre(.indie)

        #expect(singleTracks[0].genre == .indie)
        #expect(shown.genre == .rap)
        #expect(album.tracksGenre.common == .rap)
    }

    /// Порядок жанров на странице альбома остался прежним после переноса
    /// сортировки в `Genre.byFrequency`.
    @Test func albumPageListsGenresMostFrequentFirst() {
        let (album, _) = makeAlbum([.jazz, .soul, .soul, .blues, .jazz, .soul])

        #expect(album.genres == [.soul, .jazz, .blues])
    }

    // MARK: - Черновики нового альбома

    @Test func settingTheGenreOfDraftsSetsEveryDraft() {
        var drafts = [draft(.pop), draft(.rap), draft(.pop)]

        drafts.setGenre(.shoegaze)

        #expect(drafts.map(\.genre) == [.shoegaze, .shoegaze, .shoegaze])
        #expect(drafts.tracksGenre.common == .shoegaze)
    }

    /// Черновик после этого правится сам по себе — как трек в готовом альбоме.
    @Test func aDraftChangedAfterwardsMakesTheNewAlbumMixed() {
        var drafts = [draft(.pop), draft(.pop), draft(.pop)]
        drafts.setGenre(.punk)

        drafts[2].genre = .emo

        #expect(drafts.map(\.genre) == [.punk, .punk, .emo])
        #expect(drafts.tracksGenre.isMixed)
        #expect(drafts.tracksGenre.trackCount == 3)
    }

    /// Жанр меняется, а всё остальное в черновике — нет: ни имя, ни
    /// идентификатор, по которому форма находит строку.
    @Test func settingTheGenreKeepsTheRestOfTheDraft() {
        var drafts = [draft(.pop), draft(.rap)]
        let ids = drafts.map(\.id)

        drafts.setGenre(.house)

        #expect(drafts.map(\.id) == ids)
        #expect(drafts.map(\.name) == ["Draft", "Draft"])
    }
}
