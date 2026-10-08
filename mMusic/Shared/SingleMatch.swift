import Foundation

/// Узнаёт в новом файле песню, которая уже лежит в библиотеке синглом.
///
/// Сингл обычно выходит раньше альбома: его неделями слушают, ставят в плейлисты,
/// отмечают звёздочкой — а потом приходит альбом с той же песней. Второй трек
/// с нуля разорвал бы историю надвое, поэтому новый альбом забирает себе сам
/// трек сингла, а повторный файл не нужен.
///
/// Узнаёт осторожно: название и хотя бы один общий автор. Ошибка здесь не
/// молчаливая — строка в форме альбома говорит, что сингл переедет, и это можно
/// отменить, — но лучше пропустить совпадение, чем склеить две разные песни.
enum SingleMatch {

    /// Трек-сингл (или трек без альбома) с тем же названием и хотя бы одним
    /// общим автором. nil — такого нет.
    static func track(titled title: String, by artists: [String], among tracks: [Track]) -> Track? {
        let wanted = normalizedTitle(title)
        let names = Set(artists.map(normalizedName))
        // Без авторов совпадение по одному названию — лотерея: «Intro» есть у всех.
        guard !wanted.isEmpty, !names.isEmpty else { return nil }

        let candidates = tracks.filter { track in
            guard track.album == nil || track.album?.type == .single else { return false }
            guard normalizedTitle(track.name) == wanted else { return false }

            let theirs = Set(track.artistNames.map(normalizedName))
            return !names.isDisjoint(with: theirs)
        }

        // Если сингл в библиотеке уже лежит дважды, переезжает тот, что слушали
        // больше: его история и есть то, ради чего всё затевалось. Поровну —
        // тот, что старше.
        return candidates.max { a, b in
            a.playCount != b.playCount ? a.playCount < b.playCount : a.addedAt > b.addedAt
        }
    }

    /// Название без гостей: «Song (feat. B)», «Song [ft. B]» и «Song feat. B» —
    /// та же песня, что и «Song». Версии вроде «(Remix)» не трогаем: это уже другая.
    static func normalizedTitle(_ title: String) -> String {
        normalizedName(title)
            .replacing(#/\s*[(\[](feat|ft|featuring|with)\.?\s[^)\]]*[)\]]/#, with: "")
            .replacing(#/\s+(feat|ft|featuring)\.?\s.*$/#, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Регистр, диакритика, кавычки и лишние пробелы в тегах разнятся от
    /// источника к источнику, а песня от этого другой не становится.
    static func normalizedName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacing("’", with: "'")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
