import Foundation

/// Достаёт прямую ссылку на mp3 по адресу страницы трека на SoundCloud.
///
/// Публичного ключа приложения SoundCloud больше не выдаёт, поэтому `client_id`
/// вынимается из скриптов их же плеера и кешируется до перезапуска. Когда ключ
/// протухнет, запрос вернёт 401 — тогда кеш сбрасывается и ключ ищется заново.
enum SoundCloudClient {

    struct Resolved: Sendable {
        let title: String
        let artist: String
        let artworkURL: URL?
        let streamURL: URL
    }

    enum ClientError: LocalizedError {
        case notATrackLink
        case clientIDNotFound
        case trackNotFound
        case noProgressiveStream

        var errorDescription: String? {
            switch self {
            case .notATrackLink:
                "This doesn't look like a SoundCloud track link."
            case .clientIDNotFound:
                "Couldn't read SoundCloud's player key. Try again later."
            case .trackNotFound:
                "SoundCloud didn't return a track for this link."
            case .noProgressiveStream:
                "This track is only available as a stream that can't be saved."
            }
        }
    }

    /// Пережидает перезапуск приложения плохо, зато не ищется на каждый трек.
    private static let cache = ClientIDCache()

    /// Без него SoundCloud отдаёт мобильную вёрстку, где скриптов с ключом нет вовсе.
    private static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

    // MARK: - Публичный вход

    nonisolated static func resolve(_ link: String) async throws -> Resolved {
        let pageURL = try await trackURL(from: link)

        do {
            return try await resolve(pageURL, clientID: await cache.value(orFetch: fetchClientID))
        } catch ClientError.trackNotFound {
            // Ключ мог протухнуть — второй заход уже со свежим.
            await cache.clear()
            return try await resolve(pageURL, clientID: await cache.value(orFetch: fetchClientID))
        }
    }

    /// Кладёт файл в свою папку во временной директории под именем «Артист - Трек.mp3»:
    /// дальше его подхватывает обычный импорт, который такое имя умеет разбирать.
    nonisolated static func download(_ track: Resolved) async throws -> URL {
        var request = URLRequest(url: track.streamURL)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")

        let (temporaryFile, _) = try await URLSession.shared.download(for: request)

        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let name = sanitized("\(track.artist) - \(track.title)") + ".mp3"
        let destination = folder.appending(path: name)

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: temporaryFile, to: destination)

        return destination
    }

    nonisolated static func artworkData(for track: Resolved) async -> Data? {
        guard let url = track.artworkURL else { return nil }
        return try? await get(url).0
    }

    private nonisolated static func get(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")

        return try await URLSession.shared.data(for: request)
    }

    // MARK: - Шаги

    private nonisolated static func resolve(_ pageURL: URL, clientID: String) async throws -> Resolved {
        var components = URLComponents(string: "https://api-v2.soundcloud.com/resolve")!
        components.queryItems = [
            URLQueryItem(name: "url", value: pageURL.absoluteString),
            URLQueryItem(name: "client_id", value: clientID)
        ]

        let (data, response) = try await get(components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ClientError.trackNotFound }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let payload = try? decoder.decode(TrackPayload.self, from: data) else {
            throw ClientError.trackNotFound
        }

        // HLS тоже отдают, но его пришлось бы склеивать из сегментов — берём только цельный файл.
        guard let transcoding = payload.media.transcodings.first(where: { $0.format.protocol == "progressive" }) else {
            throw ClientError.noProgressiveStream
        }

        return Resolved(
            title: payload.title,
            artist: payload.user.username,
            artworkURL: highResArtwork(payload.artworkUrl),
            streamURL: try await streamURL(from: transcoding.url, clientID: clientID)
        )
    }

    /// Ссылка на transcoding отдаёт не файл, а ещё один JSON с одноразовым адресом.
    private nonisolated static func streamURL(from transcodingURL: String, clientID: String) async throws -> URL {
        guard var components = URLComponents(string: transcodingURL) else { throw ClientError.noProgressiveStream }
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "client_id", value: clientID)]

        guard let url = components.url else { throw ClientError.noProgressiveStream }

        let (data, _) = try await get(url)

        guard let payload = try? JSONDecoder().decode(StreamPayload.self, from: data),
              let streamURL = URL(string: payload.url) else {
            throw ClientError.noProgressiveStream
        }

        return streamURL
    }

    /// Ключ лежит в одном из скриптов главной страницы. Какой именно — меняется,
    /// поэтому перебираются все, с конца: нужный обычно среди последних.
    private nonisolated static func fetchClientID() async throws -> String {
        guard let home = URL(string: "https://soundcloud.com/discover") else { throw ClientError.clientIDNotFound }

        let (data, _) = try await get(home)
        guard let html = String(data: data, encoding: .utf8) else { throw ClientError.clientIDNotFound }

        for script in scriptURLs(in: html).reversed() {
            guard let url = URL(string: script),
                  let (scriptData, _) = try? await get(url),
                  let javascript = String(data: scriptData, encoding: .utf8),
                  let id = value(after: "client_id:\"", until: "\"", in: javascript) else { continue }

            return id
        }

        throw ClientError.clientIDNotFound
    }

    // MARK: - Разбор текста

    /// Кнопка «поделиться» в SoundCloud даёт короткую ссылку `on.soundcloud.com/…`
    /// и часто вместе с текстом вокруг — до адреса трека отсюда ещё надо добраться.
    private nonisolated static func trackURL(from link: String) async throws -> URL {
        guard let raw = firstURL(in: link),
              raw.host()?.contains("soundcloud.com") == true else { throw ClientError.notATrackLink }

        // Короткая ссылка — это редирект; настоящий адрес узнаём, пройдя по нему.
        let expanded = isShortLink(raw) ? await expand(raw) : raw

        // ?si=…&utm_source=… приходят от кнопки «поделиться» и API только мешают.
        var components = URLComponents(url: expanded, resolvingAgainstBaseURL: false)
        components?.query = nil

        guard let cleaned = components?.url,
              // /артист/трек — минимум два непустых сегмента, иначе это профиль или подборка.
              cleaned.pathComponents.filter({ $0 != "/" }).count >= 2 else { throw ClientError.notATrackLink }

        return cleaned
    }

    private nonisolated static func isShortLink(_ url: URL) -> Bool {
        url.host() == "on.soundcloud.com" || url.pathComponents.filter { $0 != "/" }.count < 2
    }

    /// URLSession сама идёт по редиректам, поэтому конечный адрес лежит в ответе.
    /// Не получилось — возвращаем исходный: пусть дальше отсеется по числу сегментов.
    private nonisolated static func expand(_ url: URL) async -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")

        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return url }

        return response.url ?? url
    }

    /// Вытаскивает первый адрес из вставленного текста — им может оказаться и целое
    /// «Слушай трек … https://on.soundcloud.com/…».
    private nonisolated static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)

        if let match = detector?.firstMatch(in: text, range: range), let url = match.url {
            return url
        }

        return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private nonisolated static func scriptURLs(in html: String) -> [String] {
        var found: [String] = []
        var rest = Substring(html)

        while let start = rest.range(of: "https://a-v2.sndcdn.com/assets/") {
            let tail = rest[start.lowerBound...]
            guard let end = tail.range(of: ".js") else { break }

            found.append(String(tail[..<end.upperBound]))
            rest = tail[end.upperBound...]
        }

        return found
    }

    private nonisolated static func value(after prefix: String, until suffix: String, in text: String) -> String? {
        guard let start = text.range(of: prefix) else { return nil }
        let tail = text[start.upperBound...]
        guard let end = tail.range(of: suffix) else { return nil }

        return String(tail[..<end.lowerBound])
    }

    /// В выдаче обложка приходит маленькой; крупная лежит по тому же адресу с другим суффиксом.
    private nonisolated static func highResArtwork(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        return URL(string: raw.replacingOccurrences(of: "-large.", with: "-t500x500."))
    }

    private nonisolated static func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Модели ответа

    private struct TrackPayload: Decodable {
        let title: String
        let artworkUrl: String?
        let user: User
        let media: Media

        struct User: Decodable {
            let username: String
        }
        struct Media: Decodable {
            let transcodings: [Transcoding]
        }
        struct Transcoding: Decodable {
            let url: String
            let format: Format

            struct Format: Decodable {
                let `protocol`: String
            }
        }
    }

    private struct StreamPayload: Decodable {
        let url: String
    }
}

/// Актор, потому что ключ ищут сразу несколько экранов, а искать его стоит один раз.
private actor ClientIDCache {
    private var stored: String?

    func value(orFetch fetch: @Sendable () async throws -> String) async throws -> String {
        if let stored { return stored }

        let fetched = try await fetch()
        stored = fetched
        return fetched
    }

    func clear() {
        stored = nil
    }
}
