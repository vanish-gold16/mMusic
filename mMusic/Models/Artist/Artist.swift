import Foundation
import SwiftData

@Model
class Artist {
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \Credit.artist)
    var credits: [Credit] = []
    
    init(name: String, credits: [Credit]) {
        self.name = name
        self.credits = credits
    }
}
