import Foundation

/// Релиз, который радар нашёл у артиста из библиотеки.
///
/// Это не запись в базе, а строка в своём файле радара (`RadarStore`): всё
/// здесь можно в любой момент получить из каталогов заново, а библиотеку — нет.
/// Поэтому радар и не трогает SwiftData вовсе.
nonisolated struct RadarRelease: Codable, Hashable, Sendable, Identifiable {

    enum Kind: String, Codable, Sendable {
        case album, ep, single

        var label: String {
            switch self {
            case .album: "ALBUM"
            case .ep: "EP"
            case .single: "SINGLE"
            }
        }
    }

    enum Source: String, Codable, Sendable {
        case deezer, apple

        var title: String {
            switch self {
            case .deezer: "Deezer"
            case .apple: "Apple Music"
            }
        }
    }

    /// «deezer:775438211» — номера двух каталогов друг с другом не пересекаются.
    let id: String
    let source: Source
    /// Номер релиза в его каталоге.
    let sourceID: Int
    var title: String
    var kind: Kind
    /// День выхода, как его пишет каталог: «2026-10-10». Без часов и пояса:
    /// пятничный релиз выходит в полночь по местному времени.
    var releaseDay: String
    var cover: URL?
    var link: URL?
    /// Как релиз подписан в каталоге: «VILLIAN & madk1d».
    var byline: String
    /// Кто из библиотеки на нём есть — у них он и нашёлся.
    var libraryArtists: [String]
    /// Все из библиотеки здесь только гости: релиз чужой, они на фите.
    var isFeature: Bool
    /// Когда радар его увидел.
    var foundAt: Date
    /// Когда он попадает во входящие: для вышедшего — когда нашёлся,
    /// для анонса — полночь дня выхода.
    var arrivesAt: Date
    /// Нашёлся при первом знакомстве с артистом. О таком не сообщают:
    /// это не новость, а то, что уже лежало в каталоге. На полке он есть.
    var isQuiet: Bool
    /// «Не интересно» — убран с полки.
    var isDismissed: Bool

    init(
        source: Source,
        sourceID: Int,
        title: String,
        kind: Kind,
        releaseDay: String,
        cover: URL?,
        link: URL?,
        byline: String,
        libraryArtists: [String] = [],
        isFeature: Bool = false,
        foundAt: Date = .now,
        arrivesAt: Date = .now,
        isQuiet: Bool = false,
        isDismissed: Bool = false
    ) {
        self.id = "\(source.rawValue):\(sourceID)"
        self.source = source
        self.sourceID = sourceID
        self.title = title
        self.kind = kind
        self.releaseDay = releaseDay
        self.cover = cover
        self.link = link
        self.byline = byline
        self.libraryArtists = libraryArtists
        self.isFeature = isFeature
        self.foundAt = foundAt
        self.arrivesAt = arrivesAt
        self.isQuiet = isQuiet
        self.isDismissed = isDismissed
    }

    /// Название без приписки Apple « - Single».
    var displayTitle: String {
        RadarText.withoutStoreSuffix(title)
    }
}

/// Кем артист из библиотеки оказался в каталоге.
nonisolated struct RadarMatch: Codable, Hashable, Sendable {

    enum Status: String, Codable, Sendable {
        /// В каталоге нашлись песни из библиотеки — точно он.
        case confirmed
        /// Песен не нашлось, но такое имя в каталоге одно (или один явно известнее
        /// остальных). Может быть он, а может тёзка: Deezer, бывает, сваливает
        /// в один профиль всех «Infinity» разом. Поэтому сам радар за таким
        /// не следит — ждёт «да, это он» на странице артиста.
        case probable
        /// Выбран руками.
        case picked
        /// Не нашёлся: такого имени нет или тёзок несколько и ни один
        /// не подтвердился. Через неделю радар попробует снова.
        case missing
        /// Сказали руками, что в этом каталоге его нет. Больше не ищется.
        case rejected
    }

    var id: Int?
    var name: String?
    var picture: URL?
    var status: Status
    var decidedAt: Date

    /// Следить ли за этим каталогом.
    var isWatched: Bool {
        id != nil && [.confirmed, .picked].contains(status)
    }
}

/// Всё, что радар знает про одного артиста из библиотеки.
nonisolated struct RadarArtist: Codable, Hashable, Sendable {
    var name: String
    var deezer: RadarMatch?
    var apple: RadarMatch?
    var isMuted: Bool
    /// Номера релизов, которые уже видели в каталоге. nil — с каталогом
    /// ещё не знакомились: первый проход только запоминает всё, что там
    /// лежит, иначе первая же проверка завалила бы уведомлениями о старом.
    var knownDeezer: Set<Int>?
    var knownApple: Set<Int>?
    var deezerCheckedAt: Date?
    var appleCheckedAt: Date?

    init(name: String) {
        self.name = name
        self.isMuted = false
    }

    /// Нужен ли взгляд человека: ни в одном каталоге артист не опознан
    /// наверняка, а решать ещё есть что — кто-то нашёлся только по имени
    /// или не нашёлся вовсе. «Его там нет» в обоих — уже решено.
    var needsReview: Bool {
        let statuses = [deezer?.status, apple?.status].compactMap { $0 }
        return !statuses.isEmpty
            && !statuses.contains(.confirmed) && !statuses.contains(.picked)
            && statuses.contains { $0 == .probable || $0 == .missing }
    }
}

/// Артист библиотеки, каким его видит радар: имя и названия его песен.
/// Снимок кладётся в файл радара при каждом запуске — фоновая проверка
/// идёт без базы и без интерфейса и берёт артистов отсюда.
nonisolated struct LibraryArtist: Codable, Hashable, Sendable {
    /// `RadarText.key` имени: «КИНО» и «Кино» — один артист.
    let key: String
    let name: String
    /// Ключи песен и альбомов для опознания (`RadarText.titleKeys`).
    let titleKeys: Set<String>
    /// Ключи названий целиком (`RadarText.releaseKey`): то, что уже лежит
    /// в библиотеке, новинкой не считается.
    let ownedKeys: Set<String>
    /// Несколько очищенных названий словами — для поиска треков, когда
    /// артиста не узнать по списку его релизов.
    let searchTitles: [String]
    /// Треки и прослушивания: кого слушают больше, того проверяют первым.
    let weight: Int
}

/// Файл радара целиком.
nonisolated struct RadarState: Codable, Sendable {
    var artists: [String: RadarArtist] = [:]
    var releases: [RadarRelease] = []
    var library: [LibraryArtist] = []
    /// Когда входящие открывали в последний раз: всё, что пришло позже, — непрочитанное.
    var inboxSeenAt: Date = .distantPast
    var lastCheckAt: Date?
}

/// Куда ведёт нажатие: на входящие или на один релиз.
enum RadarRoute: Hashable {
    case inbox
    case release(String)
}
