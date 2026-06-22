import Foundation
import SwiftData
import CryptoKit

@MainActor
class LibraryStore {
    let modelContext: ModelContext
    
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
        modelContext.delete(book)
        try modelContext.save()
    }
    
    func reconcileLibrary(books: [Book]) {
        var hashesSeen: [String: Book] = [:]
        
        for book in books {
            // 1. Validation: Does the physical file exist?
            let fileExists = (Self.getURL(for: book) != nil)
            if !fileExists {
                if book.failureType == .none {
                    book.failureType = .missingFile
                }
                continue
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
                    } else {
                        hashesSeen[hash] = book
                        modelContext.delete(existing)
                    }
                } else {
                    hashesSeen[hash] = book
                }
            }
            
            // 4. Normalization
            if book.readingPosition < 0.0 { book.readingPosition = 0.0 }
            if book.readingPosition > 1.0 { book.readingPosition = 1.0 }
        }
        
        try? modelContext.save()
    }
}
