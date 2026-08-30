import Foundation
import SwiftData

@Model
class Artist {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Credit.artist)
    var credits: [Credit] = []
    /// Фотография артиста. Своего изображения у артиста взяться неоткуда —
    /// в файлах трека его нет, — поэтому её ставят руками на странице артиста.
    /// Необязательное поле: у всех, кто уже есть в библиотеке, оно просто пустое.
    @Attribute(.externalStorage) var artwork: Data?

    init(name: String, credits: [Credit]) {
        self.name = name
        self.credits = credits
    }
}
