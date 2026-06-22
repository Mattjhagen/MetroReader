import Foundation
import SwiftData

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
        
        // Create the Book record
        let book = Book(
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            filename: filename
        )
        
        modelContext.insert(book)
        try modelContext.save()
        
        return book
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
}
