import Foundation

/// Статический текст трека — слова, перевод или просто заметка. Без таймкодов:
/// он не подсвечивается по ходу воспроизведения, его читают.
///
/// Здесь только разбор строки. Хранит текст сам `Track`, показывает `LyricsPanel`,
/// а вынесен разбор отдельно, чтобы его можно было проверить тестами без экрана.
enum Lyrics {

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
