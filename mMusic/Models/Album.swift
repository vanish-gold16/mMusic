import Foundation
import SwiftData

@Model
class Album {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Track.album)
    var tracks: [Track]
    var type: AlbumType
    /// Песни, которые живут в другом альбоме, а этот сингл их только показывает:
    /// сингл вышел раньше, потом песня вошла в альбом. Удаление сингла их
    /// не трогает — они остаются дома.
    @Relationship(deleteRule: .nullify, inverse: \Track.single)
    var linkedTracks: [Track] = []
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
        let counts = tracklist.reduce(into: [Genre: Int]()) { counts, track in
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

    /// Пластинки, как их показывают и играют: `discs`, и у сингла впереди ещё
    /// его песня, живущая в альбоме. Номера и раскладку правят только по
    /// `discs` — чужой трек подмешан сюда посмотреть, его номер принадлежит
    /// его альбому.
    var tracklistDiscs: [[Track]] {
        var discs = discs
        discs[0].insert(contentsOf: linkedTracks.sorted { $0.addedAt < $1.addedAt }, at: 0)
        return discs
    }

    /// Все треки пластинки подряд, в порядке показа. См. `tracklistDiscs`.
    var tracklist: [Track] {
        tracklistDiscs.flatMap { $0 }
    }

    /// Есть ли трек на этой пластинке — своим или песней с альбома.
    func contains(_ track: Track) -> Bool {
        track.album?.persistentModelID == persistentModelID
            || track.single?.persistentModelID == persistentModelID
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
    /// уезжает — альбом-дом у трека один, — но сингл свою песню не теряет:
    /// см. `takeIn(_:albumArtists:)`.
    ///
    /// `albumArtists` — авторы альбома, если на экране они новее, чем в базе.
    func append(_ tracks: [Track], albumArtists: [String]? = nil) {
        var position = self.tracks.count
        var left: [Album] = []

        for track in tracks {
            guard track.album?.persistentModelID != persistentModelID else { continue }

            if let previous = takeIn(track, albumArtists: albumArtists ?? artistNames) {
                left.append(previous)
            }

            track.album = self
            track.position = position
            // Конец альбома — это конец последней пластинки: так треки одной
            // пластинки и дальше идут подряд.
            track.disc = discCount - 1
            position += 1
        }

        Set(left).forEach { $0.tidyUpAfterLeaving() }
    }

    /// Трек переходит в этот альбом из другого. Вызывать до того, как сменится
    /// `track.album`: здесь решается, что станет с прежним альбомом. Номер и
    /// пластинку трека ставит вызывающий.
    ///
    /// Песня с сингла приходит в альбом побольше, не уходя с сингла: сингл
    /// остаётся в библиотеке со своей обложкой, датой и авторами и показывает
    /// её у себя (`Track.single`). Трек при этом один — прослушивания, звёздочка,
    /// плейлисты у сингла и альбома общие. Из любого другого альбома трек
    /// просто уходит. А на свой сингл — возвращается домой.
    ///
    /// Возвращает альбом, из которого трек ушёл, — после переезда его приводят
    /// в порядок: `tidyUpAfterLeaving()`. nil — уходить было неоткуда.
    func takeIn(_ track: Track, albumArtists: [String]) -> Album? {
        if track.single?.persistentModelID == persistentModelID {
            track.single = nil
        }

        guard let previous = track.album, previous.persistentModelID != persistentModelID else { return nil }

        if previous.type == .single, type != .single, track.single == nil {
            keepGuests(of: track, from: previous, albumArtists: albumArtists)
            track.single = previous
        }

        previous.tracks.removeAll { $0.persistentModelID == track.persistentModelID }
        return previous
    }

    /// Альбом, из которого ушли треки: закрыть дыру в нумерации, а опустевший
    /// сингл — убрать. Пустой конверт в сетке ничего не значит, а всё ценное
    /// трек увёз с собой. Сингл, который показывает песню с альбома, не пустой —
    /// он остаётся.
    func tidyUpAfterLeaving() {
        if type == .single && tracks.isEmpty && linkedTracks.isEmpty {
            modelContext?.delete(self)
        } else {
            renumberTracks()
        }
    }

    /// Перед удалением альбома: песни, вышедшие ещё и синглом, возвращаются на
    /// свои синглы, а не уходят каскадом вместе с файлами — иначе синглы
    /// остались бы пустыми. Возвращает треки, которые уйдут вместе с альбомом.
    func sendSinglesHome() -> [Track] {
        for track in Array(tracks) where track.single != nil {
            track.returnToSingle()
        }
        return tracks
    }

    /// Авторов песня брала у сингла, а в альбоме наследует авторов альбома.
    /// Тех, кого среди них нет, она оставляет за собой — иначе «Song feat. B»
    /// в альбоме A потеряла бы B. У сингла авторы остаются как были.
    private func keepGuests(of track: Track, from single: Album, albumArtists: [String]) {
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

extension Track {

    /// Песня возвращается жить на свой сингл: её альбом удаляют или её оттуда
    /// убирают. Без этого она осталась бы без альбома, а при удалении альбома
    /// ушла бы каскадом вместе с файлом. false — сингла у песни нет.
    @discardableResult
    func returnToSingle() -> Bool {
        guard let single else { return false }
        single.append([self])
        return true
    }
}
