import Foundation
import SwiftData
import SwiftUI

@Model
class Track {
    var name: String
    var album: Album?
    @Relationship(deleteRule: .cascade, inverse: \Credit.track)
    var credits: [Credit]
    var artists: [Artist] {
        let inherited = album?.artists ?? []
        let own = credits.sorted { $0.position < $1.position }
            .map { $0.artist }
        
        var seen = Set<String>()
        return (inherited + own).filter { seen.insert($0.name).inserted }
    }
    var artistNames: [String] {
        artists.map(\.name)
    }
    var genre: Genre
    var filename: String
    var isFavourite = false
    @Relationship(deleteRule: .cascade, inverse: \TrackPlaylistItem.track)
    var items: [TrackPlaylistItem] = []
    var position: Int = 0
    /// На какой пластинке альбома лежит трек, с нуля. У альбома из одной
    /// пластинки — у всех, собранных до появления пластинок, — это всегда 0.
    ///
    /// Номер пластинки только помечает трек; порядок в альбоме по-прежнему
    /// задаёт `position`, и треки одной пластинки в нём всегда идут подряд —
    /// за этим следит `Album`. Поэтому всё, что сортирует альбом по `position`,
    /// получает и правильный порядок пластинок.
    var disc: Int = 0
    /// Длительность в секундах. 0 — ещё не прочитана из файла; этим занимается
    /// `TrackDurationLoader`, поэтому у треков, импортированных до появления поля,
    /// она появится сама, без переимпорта.
    var duration: TimeInterval = 0
    
    var addedAt: Date = Date.now
    /// Форма волны: 120 байт громкости по всей длине трека. Считается один раз
    /// в `TrackWaveformLoader`, рисуется за слайдером в плеере.
    var waveform: Data?
    /// Сколько раз трек дослушивали. Считает `AudioPlayer`, а не сам запуск —
    /// иначе счётчик накручивался бы пролистыванием очереди.
    var playCount: Int = 0
    /// Когда трек в последний раз ставили играть. nil — ещё ни разу.
    /// На этом держится лента «Recently played» на главной.
    var lastPlayedAt: Date?
    
    /// Статический текст трека: слова, перевод, заметка. Открывается в плеере,
    /// синхронизации со временем нет — см. `Lyrics`.
    /// Необязательное поле со значением по умолчанию: у треков, добавленных до
    /// его появления, оно просто окажется пустым, переимпорт не нужен.
    var lyrics: String?
    /// Есть ли что показывать в панели текста. Строка из одних пробелов — нет.
    var hasLyrics: Bool {
        Lyrics.normalized(lyrics ?? "") != nil
    }

    /// Ремикс трека: положения ручек скорости, тона и эха. nil — трек звучит так,
    /// как записан. Хранятся именно числа, а не второй файл: обработка идёт вживую
    /// в звуковом тракте, оригинал на диске остаётся нетронутым.
    var remix: RemixSettings?

    /// Своя обложка трека: из тегов файла или выбранная руками. Пока трек лежит
    /// в альбоме с обложкой, её не видно — но она остаётся на месте и вернётся,
    /// если трек из альбома выйдет или у альбома обложки не станет.
    @Attribute(.externalStorage) var artwork: Data?
    /// Обложка, которую видно везде: у трека в альбоме это всегда обложка альбома.
    ///
    /// Правило, а не запасной вариант: альбом — цельная работа, и разнобой
    /// обложек внутри него означал бы, что часть треков выглядит как чужие.
    /// Сравнивается это каждый раз заново, а не переписывается в треки: смена
    /// обложки альбома тут же меняет её у всех его треков, и ничьи данные при
    /// этом не затираются.
    var displayArtwork: Data? {
        album?.artwork ?? artwork
    }

    init(name: String, album: Album? = nil, credits: [Credit], genre: Genre, filename: String, isFavourite: Bool = false, artwork: Data? = nil) {
        self.name = name
        self.album = album
        self.credits = credits
        self.genre = genre
        self.filename = filename
        self.isFavourite = isFavourite
        self.artwork = artwork
    }

}
