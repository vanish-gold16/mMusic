import Foundation

/// LRCLIB (lrclib.net) — открытая база текстов песен: без ключа, без входа,
/// бесплатно. Тексты в неё заносят сами слушатели, и у многих есть таймкоды —
/// строки LRC, по которым плеер подсвечивает то, что поётся сейчас.
nonisolated enum LRCLibClient {

    /// Запись базы. Одна песня лежит там много раз — с альбома, с концерта,
    /// со сборника, — и у каждой записи своя длительность и свои таймкоды.
    struct Record: Decodable, Equatable, Sendable {
        let id: Int
        let trackName: String
        let artistName: String
        let albumName: String?
        /// В секундах.
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private static let base = "https://lrclib.net/api"

    /// Поиск по полям: база сама сравнивает название с названием, а артиста
    /// с артистом — точнее, чем поиск по словам.
    static func search(track: String, artist: String?) async throws -> [Record] {
        var query = ["track_name": RadarText.query(track)]
        if let artist {
            query["artist_name"] = RadarText.query(artist)
        }
        return try await get("/search", query: query)
    }

    /// Поиск по словам — когда название в библиотеке не похоже на то,
    /// что лежит в базе.
    static func search(_ text: String) async throws -> [Record] {
        try await get("/search", query: ["q": RadarText.query(text)])
    }

    private static func get(_ path: String, query: [String: String]) async throws -> [Record] {
        var components = URLComponents(string: base + path)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        // LRCLIB просит подписывать запросы именем приложения: так её авторы
        // видят, кто ими пользуется, и не путают клиента с ботом.
        request.setValue("mMusic/1.0 (personal iOS player)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CatalogError.badResponse }

        return try JSONDecoder().decode([Record].self, from: data)
    }
}

/// Поиск текста для трека из библиотеки: какие запросы отправить в LRCLIB
/// и какую из найденных записей взять.
///
/// Выбор вынесен отдельно от сети, чтобы его можно было проверить тестами:
/// ошибаются здесь не запросы, а сравнение — «тот ли это трек».
nonisolated enum LyricsLookup {

    /// Что о треке знает библиотека. Снимок, а не сам `Track`: поиск ждёт сеть
    /// вне главного потока, а модель SwiftData оттуда трогать нельзя.
    struct Query: Equatable, Sendable {
        let title: String
        let artists: [String]
        /// Длительность в секундах; 0 — неизвестна.
        let duration: TimeInterval
    }

    enum Result: Equatable, Sendable {
        /// Текст и то, синхронный ли он. Синхронный — строки LRC как есть.
        case lyrics(String, isSynced: Bool)
        /// База знает трек и знает, что слов в нём нет.
        case instrumental
        case notFound
    }

    /// Насколько длительность записи может отличаться от трека, чтобы её
    /// таймкоды ещё подходили. Две-три секунды — это тишина в начале
    /// или в конце файла; больше — уже другая запись: концерт, радиоверсия.
    static let durationTolerance: TimeInterval = 3

    /// Спрашивает LRCLIB, пока не найдётся подходящая запись. Запросов
    /// не больше трёх: каждый — это ожидание, а человек смотрит на кнопку.
    static func find(_ query: Query) async throws -> Result {
        for search in searches(for: query) {
            let records: [LRCLibClient.Record]

            switch search {
            case let .fields(track, artist):
                records = try await LRCLibClient.search(track: track, artist: artist)
            case let .words(text):
                records = try await LRCLibClient.search(text)
            }

            if let result = pick(from: records, for: query) {
                return result
            }
        }

        return .notFound
    }

    // MARK: - Запросы

    enum Search: Equatable {
        case fields(track: String, artist: String?)
        case words(String)
    }

    /// Названия в библиотеке грязные — треки берут с YouTube и SoundCloud:
    /// «Alive (Official Video)», «Krewella - Alive». Поэтому сначала спрашивается
    /// название как есть, потом очищенное от приписок, потом — словами
    /// вместе с артистом.
    static func searches(for query: Query) -> [Search] {
        let artist = query.artists.first
        let clean = RadarText.variants(of: query.title).first ?? query.title

        var searches: [Search] = [.fields(track: query.title, artist: artist)]

        if RadarText.key(clean) != RadarText.key(query.title) {
            searches.append(.fields(track: clean, artist: artist))
        }

        // Артист бывает вписан прямо в название — тогда дописывать его незачем.
        if let artist, !RadarText.key(clean).contains(RadarText.key(artist)) {
            searches.append(.words("\(artist) \(clean)"))
        } else {
            searches.append(.words(clean))
        }

        return searches
    }

    // MARK: - Выбор записи

    /// Лучшая запись для трека, nil — подходящей нет.
    ///
    /// Подходит запись с тем же названием и тем же артистом — или хотя бы
    /// той же длительности: артиста база и библиотека могут писать по-разному
    /// («Кино» и «Kino»), а совпадение названия и длины почти наверняка значит
    /// ту же песню. Среди подходящих лучше та, что совпала по артисту, потом —
    /// по длительности, потом — со словами и с таймкодами.
    static func pick(from records: [LRCLibClient.Record], for query: Query) -> Result? {
        let candidates = records
            .filter(hasContent)
            .filter { titleMatches($0.trackName, query.title) }
            .map { Candidate(record: $0, query: query) }
            .filter { $0.isArtist || $0.isSameLength || query.artists.isEmpty }

        guard let best = candidates.max(by: { $0.rank < $1.rank }) else { return nil }
        let record = best.record

        // Таймкоды чужой записи разъехались бы с музыкой: у концертной версии
        // слова те же, а звучат на других секундах. От неё берутся только слова.
        let timingFits = best.isSameLength || query.duration == 0 || record.duration == nil

        if timingFits, let synced = record.syncedLyrics, let text = Lyrics.normalized(synced),
           Lyrics.synced(text) != nil {
            return .lyrics(text, isSynced: true)
        }

        if let plain = record.plainLyrics, let text = Lyrics.normalized(plain) {
            return .lyrics(text, isSynced: false)
        }

        if let synced = record.syncedLyrics, let text = Lyrics.normalized(Lyrics.plain(synced)) {
            return .lyrics(text, isSynced: false)
        }

        return .instrumental
    }

    /// Запись, примеренная к треку.
    private struct Candidate {
        let record: LRCLibClient.Record
        let isArtist: Bool
        let isSameLength: Bool
        /// На сколько секунд расходится длительность; неизвестна — бесконечно.
        let drift: TimeInterval

        init(record: LRCLibClient.Record, query: Query) {
            self.record = record

            // В базе артисты одной строкой: «A, B», «A feat. B», «A & B».
            // Хватает того, что в ней есть хоть один из артистов трека.
            let artistKey = RadarText.key(record.artistName)
            isArtist = query.artists
                .map(RadarText.key)
                .contains { !$0.isEmpty && (artistKey.contains($0) || (!artistKey.isEmpty && $0.contains(artistKey))) }

            if let duration = record.duration, query.duration > 0 {
                drift = abs(duration - query.duration)
            } else {
                drift = .infinity
            }
            isSameLength = drift <= LyricsLookup.durationTolerance
        }

        /// Больше — лучше. Расхождение со знаком минус: меньше — лучше.
        /// Запись со словами выше записи «без слов»: инструменталом трек
        /// иногда помечают по ошибке, а слова по ошибке не появляются.
        var rank: (Int, Int, Int, Int, Double) {
            let hasSynced = Lyrics.normalized(record.syncedLyrics ?? "") != nil
            let hasWords = hasSynced || Lyrics.normalized(record.plainLyrics ?? "") != nil

            return (isArtist ? 1 : 0,
                    isSameLength ? 1 : 0,
                    hasWords ? 1 : 0,
                    hasSynced ? 1 : 0,
                    -drift)
        }
    }

    private static func hasContent(_ record: LRCLibClient.Record) -> Bool {
        record.instrumental == true
            || Lyrics.normalized(record.plainLyrics ?? "") != nil
            || Lyrics.normalized(record.syncedLyrics ?? "") != nil
    }

    /// Названия совпадают целиком или по одному из вариантов без приписок:
    /// «Alive (Official Video)» в библиотеке — это «Alive» в базе.
    /// Целиком сравнивается ещё и потому, что у песни «Intro» вариантов нет:
    /// такие общие слова радар из вариантов выбрасывает.
    private static func titleMatches(_ found: String, _ title: String) -> Bool {
        RadarText.key(found) == RadarText.key(title)
            || RadarText.baseKey(found) == RadarText.baseKey(title)
            || !RadarText.titleKeys(found).isDisjoint(with: RadarText.titleKeys(title))
    }
}

extension LyricsLookup.Query {

    /// `duration` — запасная длительность, если трек свою ещё не измерил:
    /// у играющего трека её знает плеер.
    init(track: Track, duration fallback: TimeInterval = 0) {
        self.init(
            title: track.name,
            artists: track.artistNames,
            duration: track.duration > 0 ? track.duration : fallback
        )
    }
}
