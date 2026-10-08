import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    var type: AlbumType
    @Relationship(deleteRule: .cascade, inverse: \Credit.album)
    var credits: [Credit]
    var artists: [Artist] {
        credits.sorted { $0.position < $1.position }
            .map(\.artist)
    }
    var artistNames: [String] {
        artists.map(\.name)
    }
    var genres: [Genre] {
        let counts = tracks.reduce(into: [Genre: Int]()) { counts, track in
            counts[track.genre, default: 0] += 1
        }
        return counts.keys.sorted {
            if counts[$0]! != counts[$1]! {
                return counts[$0]! > counts[$1]!
            }
            return $0.rawValue < $1.rawValue
        }
    }
    var release: Date?
    var isFavourite: Bool = false
    
    var addedAt: Date = Date.now
    
    @Attribute(.externalStorage) var artwork: Data?

    /// Названия пластинок по порядку; пустая строка — пластинка без названия.
    /// Пустой список — пластинка одна: так у всех альбомов, собранных до
    /// появления пластинок, и у большинства новых.
    var discTitles: [String] = []

    /// Сколько в альбоме пластинок. Хотя бы одна есть всегда.
    var discCount: Int { max(discTitles.count, 1) }

    /// Треки по пластинкам, в порядке альбома. Пустые пластинки тоже здесь:
    /// их создают заранее, а треки кладут потом.
    var discs: [[Track]] {
        var discs = Array(repeating: [Track](), count: discCount)
        for track in tracks.sorted(by: { $0.position < $1.position }) {
            discs[clampedDisc(of: track)].append(track)
        }
        return discs
    }

    /// Пластинка трека в пределах альбома. Номер за пределами — у трека,
    /// пришедшего из альбома, где пластинок было больше: такой ложится на последнюю.
    func clampedDisc(of track: Track) -> Int {
        min(max(track.disc, 0), discCount - 1)
    }

    /// Название пластинки; пустое — названия нет.
    func title(ofDisc disc: Int) -> String {
        discTitles.indices.contains(disc) ? discTitles[disc] : ""
    }
    
    init(name: String, tracks: [Track] = [], type: AlbumType, credits: [Credit] = [], release: Date? = nil, artwork: Data? = nil) {
        self.name = name
        self.tracks = tracks
        self.type = type
        self.credits = credits
        self.release = release
        self.artwork = artwork
    }
    
    /// Кладёт треки в конец альбома — на последнюю пластинку.
    ///
    /// Только добавляет: то, что уже лежит в альбоме, остаётся на своих местах —
    /// убирают трек из альбома отдельно. Приехавший из другого альбома оттуда
    /// уезжает, и в том альбоме закрывается дыра в нумерации: альбом у трека один.
    /// Сингл, у которого так забрали его песню, уходит из библиотеки целиком —
    /// см. `inheritSingle(of:albumArtists:)`.
    ///
    /// `albumArtists` — авторы альбома, если на экране они новее, чем в базе.
    func append(_ tracks: [Track], albumArtists: [String]? = nil) {
        var position = self.tracks.count
        var touched: [Album] = []

        for track in tracks {
            guard track.album?.persistentModelID != persistentModelID else { continue }

            if let previous = track.album {
                inheritSingle(of: track, albumArtists: albumArtists ?? artistNames)
                previous.tracks.removeAll { $0.persistentModelID == track.persistentModelID }
                touched.append(previous)
            }

            track.album = self
            track.position = position
            // Конец альбома — это конец последней пластинки: так треки одной
            // пластинки и дальше идут подряд.
            track.disc = discCount - 1
            position += 1
        }

        touched.forEach { $0.renumberTracks() }

        for previous in Set(touched) where previous.type == .single && previous.tracks.isEmpty {
            modelContext?.delete(previous)
        }
    }

    /// Песня переезжает сюда со своего сингла и забирает с собой то, что сингл
    /// хранил за неё: обложку и авторов. Сингл после переезда — пустой конверт,
    /// его убирают из библиотеки, и всё это ушло бы вместе с ним.
    ///
    /// Остальное трек и так везёт сам: прослушивания (они записаны на его файл),
    /// звёздочку, плейлисты, текст, ремикс, дату добавления.
    ///
    /// Вызывать до переезда, пока `track.album` ещё сингл. `albumArtists` —
    /// авторы этого альбома: их трек унаследует и без того.
    func inheritSingle(of track: Track, albumArtists: [String]) {
        guard let single = track.album,
              single.persistentModelID != persistentModelID,
              single.type == .single
        else { return }

        // В альбоме видна обложка альбома, но своя у трека остаётся и вернётся,
        // если он из альбома выйдет. У сингла обложка лежала на конверте.
        if track.artwork == nil, let cover = single.artwork {
            track.artwork = cover
        }

        // Авторов трек брал у сингла. Тех, кого среди авторов альбома нет, он
        // оставляет за собой — иначе «Song feat. B» в альбоме A потерял бы B.
        let known = albumArtists + track.credits.map(\.artist.name)
        let carried = single.credits
            .sorted { $0.position < $1.position }
            .filter { credit in
                !known.contains { $0.caseInsensitiveCompare(credit.artist.name) == .orderedSame }
            }
        guard !carried.isEmpty else { return }

        // Авторы сингла шли впереди гостей трека — так и остаются.
        for credit in track.credits {
            credit.position += carried.count
        }
        for (position, credit) in carried.enumerated() {
            modelContext?.insert(Credit(artist: credit.artist, role: credit.role, position: position, track: track))
        }
    }

    /// Номера идут подряд с нуля, и треки каждой пластинки в них — подряд,
    /// пластинка за пластинкой. То, как должно быть всегда. По этому же признаку
    /// разовая починка находит альбомы, которые пора пересчитать: см. `AlbumNumbering`.
    var isNumberedInOrder: Bool {
        let ordered = tracks.sorted { $0.position < $1.position }
        let discs = ordered.map(clampedDisc(of:))

        return ordered.map(\.position) == Array(0..<tracks.count)
            && zip(discs, discs.dropFirst()).allSatisfy { $0 <= $1 }
    }

    /// Сплошная нумерация треков с нуля.
    ///
    /// Вызывать после всего, что вынимает трек из середины альбома: удаления из
    /// библиотеки, снятия галочки в пикере, переезда в другой альбом. Иначе в номерах
    /// остаётся дыра (1, 2, 4), а новый трек, которому позицию дают по `tracks.count`,
    /// встаёт на уже занятое место.
    ///
    /// `excluding` — для удаления: пересчитать надо до `delete`, пока ссылка на трек
    /// ещё жива, а считать его при этом уже не нужно.
    func renumberTracks(excluding removed: Track? = nil) {
        let remaining = tracks
            .filter { $0.persistentModelID != removed?.persistentModelID }
            // Сначала пластинка — её треки должны идти подряд. Дата и имя файла —
            // на случай, когда номер у двух треков одинаковый: сортировка по одному
            // лишь номеру их не различает и при каждом пересчёте могла бы менять
            // местами. Имя файла в библиотеке одно, поэтому порядок выходит один
            // и тот же всегда.
            .sorted {
                (clampedDisc(of: $0), $0.position, $0.addedAt, $0.filename)
                    < (clampedDisc(of: $1), $1.position, $1.addedAt, $1.filename)
            }

        // Только там, где номер и правда разъехался: лишняя запись помечает
        // модель изменённой и тянет за собой сохранение на ровном месте.
        for (index, track) in remaining.enumerated() {
            if track.position != index { track.position = index }

            let disc = clampedDisc(of: track)
            if track.disc != disc { track.disc = disc }
        }
    }

    /// Раскладывает альбом по пластинкам: `discs[k]` — треки пластинки `k`
    /// по порядку, `titles` — их названия. Так сохраняет свою работу редактор.
    ///
    /// Номера выдаются заново подряд, пластинка за пластинкой. Треки, которых
    /// в раскладке нет, остаются в альбоме как были — убирают трек отдельно.
    func arrange(_ discs: [[Track]], titles: [String]) {
        // У альбома из одной пластинки названий не хранится: её название
        // показывать негде, а пустой список и значит «пластинка одна».
        let newTitles = discs.count > 1 ? titles : []
        if discTitles != newTitles { discTitles = newTitles }

        var position = 0
        for (disc, discTracks) in discs.enumerated() {
            for track in discTracks {
                if track.position != position { track.position = position }
                if track.disc != disc { track.disc = disc }
                position += 1
            }
        }

        renumberTracks()
    }

    enum AlbumType: String, Codable, CaseIterable {
        case single = "single"
        case EP = "EP"
        case LP = "LP"
    }
    
}
