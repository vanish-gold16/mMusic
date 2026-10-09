import Foundation

/// Как сравнивать имена и названия из библиотеки с тем, что отдают Deezer и Apple.
///
/// Имена в библиотеке чаще всего пришли из имён файлов, а файловая система
/// хранит буквы разобранными: «ё» там — это «е» и отдельные две точки над ней.
/// На вид не отличить — и для Swift это одна и та же строка, `==` сравнивает
/// буквы, а не байты. Но в адрес запроса уходят байты, и Deezer по такому
/// имени не находит никого — так «тёмный принц» поначалу «не нашёлся»
/// вовсе. Поэтому всё, что уходит
/// в запрос, сначала собирается обратно (`query`), а всё, что сравнивается,
/// ещё и упрощается до ключа (`key`).
nonisolated enum RadarText {

    /// Имя для запроса: буквы собраны, пробелов по краям нет.
    static func query(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ключ сравнения. Регистр, точки над буквами, пробелы и знаки не в счёт:
    /// «Limp Bizkit» и «LimpBizkit» — один артист, «КИНО» и «Кино» — тоже,
    /// «тёмный» и «темный» — одно слово.
    static func key(_ text: String) -> String {
        let folded = text.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)

        return String(String.UnicodeScalarView(folded.unicodeScalars.filter(CharacterSet.alphanumerics.contains)))
    }

    /// Ключ названия релиза целиком — так, как его пишет каталог. Ремикс
    /// здесь отличается от оригинала: «Loser» и «Loser (Fcukers Remix)» —
    /// разные релизы. Срезается только приписка Apple « - Single» / « - EP»:
    /// Deezer её не пишет, и без неё один и тот же сингл из двух каталогов
    /// не узнал бы сам себя.
    static func releaseKey(_ title: String) -> String {
        key(withoutStoreSuffix(title))
    }

    /// Ключ названия без приписок в скобках: «Мало 2.0 (feat. OG Buda…)»
    /// у Apple и «Мало 2.0» у Deezer — один и тот же сингл.
    static func baseKey(_ title: String) -> String {
        key(withoutStoreSuffix(title).replacingOccurrences(of: brackets, with: " ", options: .regularExpression))
    }

    static func withoutStoreSuffix(_ title: String) -> String {
        for suffix in [" - Single", " - EP"] where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title
    }

    /// Ключи песни для опознания артиста: по ним видно, что в каталоге тот же
    /// человек, а не тёзка. Названия в библиотеке грязные — трек брали
    /// с YouTube или SoundCloud, — поэтому из одного названия выходит
    /// несколько ключей:
    /// - всё в скобках — приписки: «(Official Music Video)», «(feat. …)», «(Remix)»;
    /// - после « + » — тоже: «L.E.S. best part + slowed reverb»;
    /// - «Krewella - Alive» — имя артиста попало в название;
    /// - «Clarity x Better Off Alone» — мэшап, и годится каждая из песен.
    ///
    /// Чистит радар это только у себя в памяти: в библиотеке ничего не меняется.
    static func titleKeys(_ title: String) -> Set<String> {
        Set(variants(of: title).map(key))
    }

    /// Те же варианты названия, но словами, а не ключами: они идут в поиск
    /// треков, когда артиста не узнать по списку его релизов.
    static func variants(of title: String) -> [String] {
        var base = withoutStoreSuffix(title)
            .replacingOccurrences(of: brackets, with: " ", options: .regularExpression)

        if let plus = base.range(of: " + ") {
            base = String(base[..<plus.lowerBound])
        }

        var variants = [base]
        variants += base.components(separatedBy: " - ")
        variants += base.components(separatedBy: " x ")
        variants += base.components(separatedBy: " X ")

        var seen = Set<String>()
        return variants
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { variant in
                let key = key(variant)
                return key.count >= 2 && !genericTitles.contains(key) && seen.insert(key).inserted
            }
    }

    /// Всё в круглых и квадратных скобках.
    private static let brackets = #"\([^)]*\)|\[[^\]]*\]"#

    /// Названия, которые есть у кого угодно: совпадение по ним не доказывает,
    /// что это тот самый артист.
    private static let genericTitles: Set<String> = [
        "single", "ep", "album", "intro", "outro", "interlude", "skit",
        "remix", "remixes", "demo", "live", "instrumental", "untitled", "bonus", "edit"
    ]
}
