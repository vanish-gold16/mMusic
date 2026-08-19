import Foundation
import SwiftData

extension ModelContext {
    /// Артисты дедуплицируются по имени в момент создания: искать существующего дешевле,
    /// чем потом сводить дубли в базе.
    func findOrCreateArtist(named name: String) -> Artist {
        let descriptor = FetchDescriptor<Artist>(predicate: #Predicate { $0.name == name })
        if let existing = try? fetch(descriptor).first { return existing }
        let new = Artist(name: name, credits: [])
        insert(new)
        return new
    }
}
