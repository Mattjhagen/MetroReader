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
    var totalPages: Int?
    
    var readingProgress: Double {
        guard let total = totalPages, total > 0 else { return 0.0 }
        guard let current = lastPage else { return 0.0 }
        // +1 because pages are 0-indexed, so page 0 of 1 is 100%
        return Double(current + 1) / Double(total)
    }
    
    var isCompleted: Bool {
        // Soft completion threshold (e.g. 95%) to avoid strict finishing requirements
        return readingProgress >= 0.95
    }
    
    init(id: UUID = UUID(), title: String, author: String, filename: String, dateAdded: Date = .now, lastOpenedAt: Date? = nil, lastPage: Int? = nil, isFavorite: Bool = false, totalPages: Int? = nil) {
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
