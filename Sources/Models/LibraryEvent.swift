import Foundation
import SwiftData

enum LibraryEventType: String, Codable {
    case imported
    case merged
    case removed
    case repaired
}

@Model
final class LibraryEvent {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var eventType: LibraryEventType
    var bookId: UUID
    
    init(id: UUID = UUID(), timestamp: Date = .now, eventType: LibraryEventType, bookId: UUID) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.bookId = bookId
    }
}
