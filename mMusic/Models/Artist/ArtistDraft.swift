import Foundation

struct ArtistDraft: Identifiable {
    let id = UUID()
    var name: String
    var role: CreditRole = .main
}
