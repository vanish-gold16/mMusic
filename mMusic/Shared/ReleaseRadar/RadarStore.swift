import Foundation

/// Файл радара в Application Support, рядом с базой, но не в ней.
///
/// Радар нарочно не трогает SwiftData: всё, что он хранит, можно в любой
/// момент получить из каталогов заново, а ради кэша менять схему базы
/// с настоящей библиотекой незачем. Пропал или не прочитался файл — радар
/// просто познакомится с каталогами заново, молча.
nonisolated enum RadarStore {

    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "ReleaseRadar.json")
    }

    static func load(from url: URL = url) -> RadarState {
        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(RadarState.self, from: data) else { return RadarState() }
        return state
    }

    static func save(_ state: RadarState, to url: URL = url) {
        guard let data = try? encoder.encode(state) else { return }

        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Атомарно: фоновая проверка может оборваться на полуслове, и
        // недописанный файл означал бы знакомство с каталогами с нуля.
        try? data.write(to: url, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
