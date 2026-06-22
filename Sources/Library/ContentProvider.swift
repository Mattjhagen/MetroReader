import SwiftUI

public struct ReaderCapabilities {
    public let canChangeTypography: Bool
    public let canChangeTheme: Bool
    
    public init(canChangeTypography: Bool, canChangeTheme: Bool) {
        self.canChangeTypography = canChangeTypography
        self.canChangeTheme = canChangeTheme
    }
}

public protocol ContentProvider {
    var book: Book { get }
    var fileURL: URL { get }
    
    init(book: Book, fileURL: URL)
    
    /// Loads the document into memory or prepares it for rendering.
    func load() async throws 
    
    /// Total units of content (Pages for PDF, Spine items for EPUB)
    var totalUnits: Int { get }
    
    /// The capabilities supported by this provider's format
    var capabilities: ReaderCapabilities { get }
    
    /// The current reading position, mapped to the unit index
    var currentUnit: Int { get }
    
    /// Command the provider to navigate to a specific unit
    func go(to unitIndex: Int)
    
    /// Advance to the next or previous logical unit
    func advance(forward: Bool)
    
    /// Returns the SwiftUI View that renders this specific format.
    @MainActor func renderView() -> AnyView 
}
