import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var filename: String // The name of the file in the Documents directory
    var dateAdded: Date
    var isFavorite: Bool
    var lastOpenedAt: Date?
    var readingPosition: Double // 0.0 to 1.0
    
    var readingProgress: Double {
        return readingPosition
    }
    
    var isCompleted: Bool {
        // Soft completion threshold
        return readingPosition >= 0.95
    }
    
    var shouldAutoResume: Bool {
        guard let lastOpened = lastOpenedAt else { return false }
        let hoursSinceOpen = Calendar.current.dateComponents([.hour], from: lastOpened, to: .now).hour ?? 0
        
        return hoursSinceOpen <= 72 && readingPosition > 0 && !isCompleted
    }
    
    init(id: UUID = UUID(), title: String, author: String, filename: String, dateAdded: Date = .now, lastOpenedAt: Date? = nil, readingPosition: Double = 0.0, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.author = author
        self.filename = filename
        self.dateAdded = dateAdded
        self.lastOpenedAt = lastOpenedAt
        self.readingPosition = readingPosition
        self.isFavorite = isFavorite
    }
}
