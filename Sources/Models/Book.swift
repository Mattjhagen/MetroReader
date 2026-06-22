import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var filename: String // The name of the file in the Documents directory
    var dateAdded: Date
    var lastOpenedAt: Date?
    var lastPage: Int?
    var isFavorite: Bool
    
    init(id: UUID = UUID(), title: String, author: String, filename: String, dateAdded: Date = .now, lastOpenedAt: Date? = nil, lastPage: Int? = nil, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.author = author
        self.filename = filename
        self.dateAdded = dateAdded
        self.lastOpenedAt = lastOpenedAt
        self.lastPage = lastPage
        self.isFavorite = isFavorite
    }
}
