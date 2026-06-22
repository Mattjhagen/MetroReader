import Foundation
import SwiftData

enum BookFailureType: String, Codable {
    case none
    case missingFile
    case corruptFile
    case unsupportedFormat
    case unreadableMetadata
    case partialParse
}

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var filename: String // The name of the file in the Documents directory
    var dateAdded: Date
    var isFavorite: Bool
    var failureType: BookFailureType
    var contentHash: String?
    var lastOpenedAt: Date?
    var readingPosition: Double // 0.0 to 1.0
    var lastKnownGoodPosition: Double // Safe continuity fallback
    var clusterId: String // Human-level conceptual grouping
    
    var readingProgress: Double {
        return readingPosition
    }
    
    var isCompleted: Bool {
        // Soft completion threshold
        return readingPosition >= 0.95
    }
    
    var isDamaged: Bool {
        return failureType != .none
    }
    
    var shouldAutoResume: Bool {
        guard let lastOpened = lastOpenedAt else { return false }
        let hoursSinceOpen = Calendar.current.dateComponents([.hour], from: lastOpened, to: .now).hour ?? 0
        
        return hoursSinceOpen <= 72 && readingPosition > 0 && !isCompleted
    }
    
    init(id: UUID = UUID(), title: String, author: String, filename: String, dateAdded: Date = .now, lastOpenedAt: Date? = nil, readingPosition: Double = 0.0, lastKnownGoodPosition: Double = 0.0, isFavorite: Bool = false, failureType: BookFailureType = .none, contentHash: String? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.filename = filename
        self.dateAdded = dateAdded
        self.lastOpenedAt = lastOpenedAt
        self.readingPosition = readingPosition
        self.lastKnownGoodPosition = lastKnownGoodPosition
        self.isFavorite = isFavorite
        self.failureType = failureType
        self.contentHash = contentHash
        self.clusterId = Self.generateClusterId(title: title, author: author)
    }
    
    static func generateClusterId(title: String, author: String) -> String {
        let combined = "\(title) \(author)"
        let stripped = combined.components(separatedBy: .alphanumerics.inverted).joined()
        return stripped.lowercased()
    }
}
