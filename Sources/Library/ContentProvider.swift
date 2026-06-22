import SwiftUI

public protocol ContentProvider {
    var book: Book { get }
    var fileURL: URL { get }
    
    init(book: Book, fileURL: URL)
    
    /// Loads the document into memory or prepares it for rendering.
    func load() async throws 
    
    /// Returns the SwiftUI View that renders this specific format.
    @MainActor func renderView() -> AnyView 
}
