import Foundation
import SwiftData
import CryptoKit

enum LibraryStatus: Equatable {
    case idle
    case checking
    case repairing
    case syncing
    case complete
}

@MainActor
@Observable
class LibraryStore {
    let modelContext: ModelContext
    var syncStatus: LibraryStatus = .idle
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func importPDF(from url: URL) throws -> Book {
        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let booksDir = appSupportDir.appendingPathComponent("Books", isDirectory: true)
        
        if !fileManager.fileExists(atPath: booksDir.path) {
            try fileManager.createDirectory(at: booksDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let filename = UUID().uuidString + ".pdf"
        let destinationURL = booksDir.appendingPathComponent(filename)
        
        // Ensure we have access to the security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Copy the file if it doesn't already exist at the destination
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.copyItem(at: url, to: destinationURL)
        }
        
        // Calculate simple hash
        let hash = Self.computeHash(for: destinationURL)
        
        // Create the Book record
        let book = Book(
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            filename: filename,
            contentHash: hash
        )
        
        modelContext.insert(book)
        
        let event = LibraryEvent(eventType: .imported, bookId: book.id)
        modelContext.insert(event)
        
        try modelContext.save()
        
        return book
    }
    
    static func computeHash(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func getURL(for book: Book) -> URL? {
        do {
            let appSupportDir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = appSupportDir.appendingPathComponent("Books").appendingPathComponent(book.filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func deleteBook(_ book: Book) throws {
        // 1. Remove the physical file
        if let url = Self.getURL(for: book) {
            try FileManager.default.removeItem(at: url)
        }
        
        // 2. Remove from SwiftData
        let bookId = book.id
        modelContext.delete(book)
        
        let event = LibraryEvent(eventType: .removed, bookId: bookId)
        modelContext.insert(event)
        
        try modelContext.save()
    }
    
    func reconcileLibrary(books: [Book]) {
        self.syncStatus = .checking
        var didWork = false
        var hashesSeen: [String: Book] = [:]
        
        for book in books {
            // 1. Validation: Does the physical file exist?
            let fileExists = (Self.getURL(for: book) != nil)
            if !fileExists {
                if book.failureType == .none {
                    book.failureType = .missingFile
                }
                continue
            } else if book.failureType == .missingFile {
                self.syncStatus = .repairing
                book.failureType = .none
                let event = LibraryEvent(eventType: .repaired, bookId: book.id)
                modelContext.insert(event)
                didWork = true
            }
            
            // 2. Identity Hashing: Ensure hash exists
            if book.contentHash == nil, let url = Self.getURL(for: book) {
                book.contentHash = Self.computeHash(for: url)
            }
            
            // 3. Deduplication
            if let hash = book.contentHash {
                if let existing = hashesSeen[hash] {
                    // Duplicate found. Keep the one with the most progress, or the oldest.
                    let keepExisting = existing.readingPosition > book.readingPosition || (existing.readingPosition == book.readingPosition && existing.dateAdded <= book.dateAdded)
                    
                    if keepExisting {
                        modelContext.delete(book)
                        didWork = true
                    } else {
                        hashesSeen[hash] = book
                        modelContext.delete(existing)
                        didWork = true
                    }
                } else {
                    hashesSeen[hash] = book
                }
            }
            
            // 4. Normalization
            if book.readingPosition < 0.0 { book.readingPosition = 0.0 }
            if book.readingPosition > 1.0 { book.readingPosition = 1.0 }
        }
        
        // 5. Cross-Cluster Progress Sync (Conditional)
        var clusterHighWatermarks: [String: Double] = [:]
        
        for book in books {
            // Group by clusterId AND extension to ensure format compatibility
            guard let url = Self.getURL(for: book) else { continue }
            let ext = url.pathExtension.lowercased()
            let syncKey = "\(book.clusterId)_\(ext)"
            
            let currentHigh = clusterHighWatermarks[syncKey] ?? 0.0
            if book.readingPosition > currentHigh {
                clusterHighWatermarks[syncKey] = book.readingPosition
            }
        }
        
        for book in books {
            guard let url = Self.getURL(for: book) else { continue }
            let ext = url.pathExtension.lowercased()
            let syncKey = "\(book.clusterId)_\(ext)"
            
            if let high = clusterHighWatermarks[syncKey], book.readingPosition < high {
                self.syncStatus = .syncing
                book.readingPosition = high
                didWork = true
            }
        }
        
        // 6. Prune old events
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<LibraryEvent>()
        if let events = try? modelContext.fetch(descriptor) {
            for event in events {
                if event.timestamp < thirtyDaysAgo {
                    modelContext.delete(event)
                }
            }
        }
        
        try? modelContext.save()
        
        if didWork {
            self.syncStatus = .complete
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.syncStatus = .idle
            }
        } else {
            self.syncStatus = .idle
        }
    }
}
