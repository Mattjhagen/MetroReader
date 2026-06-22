import SwiftUI

public protocol ContentProvider {
    var book: Book { get }
    var fileURL: URL { get }
    
    init(book: Book, fileURL: URL)
    
    /// Loads the document into memory or prepares it for rendering.
    func load() async throws 
    
    /// Total units of content (Pages for PDF, Spine items for EPUB)
    var totalUnits: Int { get }
    
    /// The current reading position, mapped to the unit index
    var currentUnit: Int { get }
    
    /// Command the provider to navigate to a specific unit
    func go(to unitIndex: Int)
    
    /// Returns the SwiftUI View that renders this specific format.
    @MainActor func renderView() -> AnyView 
}
