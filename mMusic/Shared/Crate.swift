import Foundation
import SwiftData

/// Один ящик в библиотеке: метка разделителя и то, что за ним. Метка —
/// диапазон от первого ключа до последнего, если в ящик слились соседние буквы.
/// Так разложены альбомы и артисты.
struct Crate<Item: PersistentModel>: Identifiable {
    let firstKey: String
    var lastKey: String
    var items: [Item]

    var title: String {
        firstKey == lastKey ? firstKey : "\(firstKey)–\(lastKey)"
    }

    /// По первому в ящике: метка может повториться — «#» бывает и в начале,
    /// и в конце алфавита, если имя начинается с эмодзи.
    var id: PersistentIdentifier { items[0].persistentModelID }

    /// Соседние с одинаковой меткой — в один ящик. Идём по уже отсортированному
    /// списку, поэтому порядок внутри ящиков тот же.
    static func grouping(_ items: [Item], by key: (Item) -> String) -> [Crate] {
        var crates: [Crate] = []

        for item in items {
            let key = key(item)
            if crates.last?.lastKey == key {
                crates[crates.count - 1].items.append(item)
            } else {
                crates.append(Crate(firstKey: key, lastKey: key, items: [item]))
            }
        }

        return crates
    }

    /// На одну букву обычно приходится одна-две вещи, и ящик на каждую был бы
    /// полупустым. Соседние буквы сливаются, пока в ящике не наберётся
    /// `minimum`, — как «B–D» на разделителе в музыкальном магазине.
    ///
    /// «#» ни с кем не сливается: «#–A» не читается. Кириллица не сливается
    /// с латиницей: «X–Б» не диапазон, а два разных алфавита.
    static func mergingSparse(_ crates: [Crate], minimum: Int) -> [Crate] {
        var merged: [Crate] = []

        for crate in crates {
            if let last = merged.last, last.items.count < minimum,
               canMerge(last.lastKey, crate.firstKey) {
                merged[merged.count - 1].items += crate.items
                merged[merged.count - 1].lastKey = crate.lastKey
            } else {
                merged.append(crate)
            }
        }

        // Хвост алфавита, которому не хватило соседей, — к предыдущему ящику:
        // одинокая «Z» в конце была бы той же полупустой строкой.
        if merged.count > 1, let tail = merged.last, tail.items.count < minimum,
           canMerge(merged[merged.count - 2].lastKey, tail.firstKey) {
            merged.removeLast()
            merged[merged.count - 1].items += tail.items
            merged[merged.count - 1].lastKey = tail.lastKey
        }

        return merged
    }

    private static func canMerge(_ left: String, _ right: String) -> Bool {
        left != "#" && right != "#" && isCyrillic(left) == isCyrillic(right)
    }

    private static func isCyrillic(_ key: String) -> Bool {
        key.unicodeScalars.first.map { (0x0400...0x04FF).contains($0.value) } ?? false
    }
}

extension String {

    /// Буква указателя для имени: первая буква заглавной. Цифры, знаки
    /// и эмодзи — под одним «#», как в конце алфавитного указателя.
    var crateLetter: String {
        guard let first = trimmingCharacters(in: .whitespaces).first, first.isLetter else {
            return "#"
        }
        return String(first).uppercased()
    }
}
