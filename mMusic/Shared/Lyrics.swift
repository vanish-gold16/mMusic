import Foundation

/// Текст трека — слова, перевод или просто заметка. Бывает двух видов:
/// - обычный: его читают куплетами, по ходу воспроизведения он не движется;
/// - синхронный, в формате LRC (`[01:23.45] слова`): так его отдаёт LRCLIB,
///   и плеер подсвечивает строку, которая звучит сейчас.
///
/// Оба вида лежат в одном поле `Track.lyrics` — вид узнаётся по самому тексту.
/// Так у синхронного текста нет отдельной копии, которая могла бы разойтись
/// с обычной, а в редакторе таймкоды можно поправить руками.
///
/// Здесь только разбор строки. Хранит текст сам `Track`, показывает `LyricsPanel`,
/// а вынесен разбор отдельно, чтобы его можно было проверить тестами без экрана.
nonisolated enum Lyrics {

    /// Текст, готовый к сохранению. Пустая строка и строка из одних пробелов
    /// превращаются в nil: по «есть ли текст» плеер решает, чем рисовать кнопку,
    /// и «пусто, но не nil» открывало бы пустую панель.
    static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Куплеты — куски текста, разделённые пустой строкой. Разносит их по вертикали
    /// сам макет, поэтому пустые строки в разметку не попадают.
    ///
    /// Пустой считается и строка из пробелов: текст обычно приходит копипастой
    /// с сайта, а там бывает всякое.
    static func stanzas(of text: String) -> [String] {
        var stanzas: [String] = []
        var current: [String] = []

        for line in lines(of: text) {
            let line = line.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                // Пустая строка закрывает куплет. Несколько подряд не плодят
                // пустых куплетов — закрывать уже нечего.
                if !current.isEmpty {
                    stanzas.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(line)
            }
        }

        if !current.isEmpty {
            stanzas.append(current.joined(separator: "\n"))
        }

        return stanzas
    }

    /// Перевод строки из Windows (`\r\n`) и старого Mac (`\r`) сводится к `\n`.
    /// Иначе `\r\n` дал бы между собой пустую строку — и каждый перенос читался бы
    /// как разрыв куплета.
    private static func lines(of text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }
}

// MARK: - Синхронный текст

nonisolated extension Lyrics {

    /// Строка синхронного текста и секунда трека, с которой она звучит.
    /// Пустой `text` — проигрыш: в LRC это метка времени без слов.
    struct Line: Equatable, Sendable {
        let time: TimeInterval
        let text: String
    }

    /// Строки LRC по порядку звучания. nil — текст обычный, без таймкодов.
    ///
    /// Синхронным текст считается, когда метки стоят хотя бы у половины строк:
    /// одна случайная «[00:30]» в заметке не должна превращать её в караоке,
    /// а пара строк без метки в настоящем LRC — ломать его. Такие строки
    /// не теряются, а продолжают предыдущую.
    static func synced(_ text: String) -> [Line]? {
        var result: [Line] = []
        var timed = 0
        var untimed = 0
        var offset: TimeInterval = 0

        for raw in lines(of: text) {
            let raw = raw.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { continue }

            let (times, rest) = timestamps(in: raw)

            if times.isEmpty {
                // «[ar: …]», «[ti: …]» — подписи файла, не текст. «[offset: …]»
                // сдвигает все метки сразу, и место в файле у неё может быть любое.
                if let (key, value) = tag(raw) {
                    if key == "offset", let milliseconds = Double(value) {
                        offset = milliseconds / 1000
                    }
                    continue
                }

                untimed += 1
                if let last = result.popLast() {
                    let joined = last.text.isEmpty ? raw : last.text + "\n" + raw
                    result.append(Line(time: last.time, text: joined))
                } else {
                    // До первой метки продолжать нечего — строка звучит с начала.
                    result.append(Line(time: 0, text: raw))
                }
                continue
            }

            timed += 1
            let words = withoutWordStamps(rest)
            // У припева метки бывают сразу все: «[00:40.00][01:30.00] слова» —
            // одна запись на каждый раз, когда он звучит.
            for time in times {
                result.append(Line(time: time, text: words))
            }
        }

        guard timed > 0, timed >= untimed else { return nil }

        // Положительный offset по правилам LRC значит «показывать раньше».
        return result
            .map { Line(time: max(0, $0.time - offset), text: $0.text) }
            .enumerated()
            // Сортировка устойчивая вручную: при равном времени строки идут
            // в том порядке, в каком написаны.
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
    }

    /// Текст без таймкодов: для превью в правке трека и для поиска по словам.
    /// Проигрыши становятся пустой строкой — то есть разрывом куплета.
    /// Обычный текст возвращается как есть.
    static func plain(_ text: String) -> String {
        guard let lines = synced(text) else { return text }

        return stanzas(of: lines.map(\.text).joined(separator: "\n"))
            .joined(separator: "\n\n")
    }

    /// Строка, которая звучит в момент `time`: последняя из начавшихся.
    /// nil — первая ещё не началась.
    static func activeIndex(in lines: [Line], at time: TimeInterval) -> Int? {
        lines.lastIndex { $0.time <= time }
    }

    // MARK: Разбор метки

    /// Метки времени в начале строки и всё, что после них.
    private static func timestamps(in line: String) -> ([TimeInterval], Substring) {
        var rest = Substring(line)
        var times: [TimeInterval] = []

        while rest.hasPrefix("["),
              let close = rest.firstIndex(of: "]"),
              let time = seconds(rest[rest.index(after: rest.startIndex)..<close]) {
            times.append(time)
            rest = rest[rest.index(after: close)...]
        }

        return (times, rest)
    }

    /// «01:23.45», «1:23», «01:23:45», «01:23.456» — в секунды.
    /// Всё остальное в квадратных скобках — не время.
    private static func seconds(_ stamp: Substring) -> TimeInterval? {
        let parts = stamp.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              parts[0].allSatisfy(\.isASCIIDigit),
              let minutes = Double(parts[0]) else { return nil }

        // Доли секунды пишут и через точку, и через двоеточие.
        let rest = parts[1].replacingOccurrences(of: ":", with: ".")
        guard rest.allSatisfy({ $0.isASCIIDigit || $0 == "." }),
              let seconds = Double(rest), seconds < 60 else { return nil }

        return minutes * 60 + seconds
    }

    /// «[ar: Artist]» → ("ar", "Artist"). Только известные подписи LRC:
    /// «[Chorus: Artist]» — это уже слова песни, а не подпись файла.
    private static func tag(_ line: String) -> (String, String)? {
        guard line.hasPrefix("["), line.hasSuffix("]"),
              let colon = line.firstIndex(of: ":") else { return nil }

        let key = line[line.index(after: line.startIndex)..<colon].lowercased()
        guard fileTags.contains(key) else { return nil }

        let value = line[line.index(after: colon)..<line.index(before: line.endIndex)]
        return (key, value.trimmingCharacters(in: .whitespaces))
    }

    private static let fileTags: Set<String> = [
        "ar", "al", "ti", "au", "by", "length", "offset", "re", "ve", "tool", "#"
    ]

    /// Расширенный LRC размечает ещё и каждое слово: «<00:12.30> слово».
    /// Подсвечивает плеер строками, поэтому эти метки просто убираются.
    private static func withoutWordStamps(_ text: Substring) -> String {
        text
            .replacingOccurrences(of: #"<\d+:\d+(?:[.:]\d+)?>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

private extension Character {
    nonisolated var isASCIIDigit: Bool { isASCII && isNumber }
}
