import Foundation

/// Не чаще одного запроса в `interval`. Оба каталога открыты без ключа,
/// но с пределом: Deezer — 50 запросов за 5 секунд, Apple — около 20
/// в минуту. Выше предела они начинают отказывать, и проверка встала бы
/// посреди библиотеки.
actor RequestGate {

    private let interval: Duration
    private var next = ContinuousClock.now

    init(interval: Duration) {
        self.interval = interval
    }

    func wait() async throws {
        let now = ContinuousClock.now
        let slot = max(next, now)
        next = slot + interval

        if slot > now {
            try await Task.sleep(until: slot, clock: .continuous)
        }
    }

    /// Каталог попросил притормозить — следующий запрос не раньше чем через `pause`.
    func back(off pause: Duration) {
        next = max(next, ContinuousClock.now + pause)
    }
}

enum CatalogError: Error {
    case badResponse
    /// Каталог сказал «слишком часто».
    case throttled
}

// MARK: - Deezer

/// Открытый API Deezer: без ключа и без входа. Отсюда радар берёт релизы,
/// где артист — главный: альбомы, EP и синглы, вместе с анонсами на будущие
/// даты.
nonisolated enum DeezerClient {

    struct Artist: Decodable, Sendable {
        let id: Int
        let name: String
        let fans: Int?
        let picture: URL?

        enum CodingKeys: String, CodingKey {
            case id, name
            case fans = "nb_fan"
            case picture = "picture_medium"
        }
    }

    struct Album: Decodable, Sendable {
        let id: Int
        let title: String
        let releaseDate: String?
        let recordType: String?
        let cover: URL?
        let link: URL?

        enum CodingKeys: String, CodingKey {
            case id, title, link
            case releaseDate = "release_date"
            case recordType = "record_type"
            case cover = "cover_big"
        }
    }

    struct Track: Decodable, Sendable {
        let id: Int
        let title: String
        let duration: Int?
        let artist: Named?
        let contributors: [Named]?
    }

    struct Named: Decodable, Sendable {
        let id: Int
        let name: String
    }

    /// Альбом целиком — для карточки релиза: треки и все, кто его подписал.
    struct AlbumDetail: Decodable, Sendable {
        let id: Int
        let title: String
        let contributors: [Named]?
        let tracks: Page<Track>?
    }

    struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
        let data: [Item]?
        let next: URL?
    }

    /// Ошибку Deezer кладёт в обычный ответ со статусом 200: `{"error": {"code": 4}}`.
    private struct Failure: Decodable, Sendable {
        struct Body: Decodable, Sendable {
            let code: Int?
        }
        let error: Body?
    }

    private static let gate = RequestGate(interval: .milliseconds(130))
    private static let base = "https://api.deezer.com"

    static func searchArtists(named name: String) async throws -> [Artist] {
        let page: Page<Artist> = try await get("/search/artist", query: ["q": RadarText.query(name), "limit": "10"])
        return page.data ?? []
    }

    /// Все релизы артиста. Список отдаётся страницами и не по дате — альбомы,
    /// потом EP, потом синглы, — поэтому читается до конца.
    static func albums(ofArtist id: Int) async throws -> [Album] {
        var page: Page<Album> = try await get("/artist/\(id)/albums", query: ["limit": "100"])
        var albums = page.data ?? []

        // Пять страниц — 500 релизов: дальше только у тех, кто выпускает
        // по ремиксу в неделю, и новое у них всё равно на первых.
        for _ in 0..<4 {
            guard let next = page.next else { break }
            page = try await get(next)
            albums += page.data ?? []
        }

        return albums
    }

    /// Самые слушаемые треки — второй источник названий для опознания артиста.
    static func searchTracks(_ query: String) async throws -> [Track] {
        let page: Page<Track> = try await get("/search", query: ["q": RadarText.query(query), "limit": "10"])
        return page.data ?? []
    }

    static func topTitles(ofArtist id: Int) async throws -> [String] {
        let page: Page<Track> = try await get("/artist/\(id)/top", query: ["limit": "50"])
        return (page.data ?? []).map(\.title)
    }

    static func album(_ id: Int) async throws -> AlbumDetail {
        try await get(URL(string: "\(base)/album/\(id)")!)
    }

    // MARK: - Запросы

    private static func get<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        var components = URLComponents(string: base + path)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await get(components.url!)
    }

    private static func get<T: Decodable>(_ url: URL) async throws -> T {
        // Второй заход — только после «слишком часто»: Deezer отвечает на это
        // кодом 4 внутри обычного ответа, а не статусом.
        for attempt in 0..<2 {
            try await gate.wait()

            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CatalogError.badResponse }

            if let failure = try? JSONDecoder().decode(Failure.self, from: data), let code = failure.error?.code {
                // 4 — «слишком часто», остальное — настоящая ошибка запроса.
                guard code == 4 else { throw CatalogError.badResponse }
                await gate.back(off: .seconds(5))
                if attempt == 0 { continue }
                throw CatalogError.throttled
            }

            return try JSONDecoder().decode(T.self, from: data)
        }

        throw CatalogError.throttled
    }
}

// MARK: - Apple

/// Поиск iTunes — открытый каталог Apple Music, тоже без ключа. Медленный
/// (около 20 запросов в минуту), зато знает фиты: в песнях артиста есть
/// и чужие релизы, где он гость, — у Deezer в списке релизов их нет.
nonisolated enum AppleMusicClient {

    struct Artist: Decodable, Sendable {
        let artistId: Int
        let artistName: String
        let primaryGenreName: String?
    }

    struct Song: Decodable, Sendable {
        let wrapperType: String
        let trackId: Int?
        let trackName: String?
        let artistId: Int?
        let artistName: String?
        let collectionId: Int?
        let collectionName: String?
        /// «Various Artists» у сборников.
        let collectionArtistName: String?
        let collectionViewUrl: URL?
        let artworkUrl100: String?
        let releaseDate: String?
        let trackNumber: Int?
        let discNumber: Int?
        let trackTimeMillis: Int?
        let trackCount: Int?
    }

    private struct Response<Item: Decodable & Sendable>: Decodable, Sendable {
        let results: [Item]
    }

    private static let gate = RequestGate(interval: .milliseconds(3200))

    static func searchArtists(named name: String) async throws -> [Artist] {
        let response: Response<Artist> = try await get("search", query: [
            "term": RadarText.query(name), "entity": "musicArtist", "limit": "10"
        ])
        return response.results
    }

    /// Песни артиста, свежие впереди, — и свои, и где он на фите. Первая
    /// строка ответа — сам артист, её отбрасываем.
    static func songs(ofArtist id: Int) async throws -> [Song] {
        let response: Response<Song> = try await get("lookup", query: [
            "id": "\(id)", "entity": "song", "limit": "200", "sort": "recent"
        ])
        return response.results.filter { $0.wrapperType == "track" }
    }

    static func tracks(ofCollection id: Int) async throws -> [Song] {
        let response: Response<Song> = try await get("lookup", query: ["id": "\(id)", "entity": "song"])
        return response.results.filter { $0.wrapperType == "track" }
    }

    /// Обложка приходит 100×100; крупная лежит по тому же адресу с другим размером.
    static func artwork(_ raw: String?, side: Int = 600) -> URL? {
        guard let raw else { return nil }
        return URL(string: raw.replacingOccurrences(of: "100x100bb", with: "\(side)x\(side)bb"))
    }

    private static func get<T: Decodable>(_ path: String, query: [String: String]) async throws -> T {
        var components = URLComponents(string: "https://itunes.apple.com/" + path)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }

        try await gate.wait()
        let (data, response) = try await URLSession.shared.data(from: components.url!)

        switch (response as? HTTPURLResponse)?.statusCode {
        case 200:
            return try JSONDecoder().decode(T.self, from: data)
        case 403, 429:
            // Перебрали предел — Apple отказывает минуту-другую.
            await gate.back(off: .seconds(90))
            throw CatalogError.throttled
        default:
            throw CatalogError.badResponse
        }
    }
}
