import SwiftUI

public struct MetroTheme {
    public static let spacing: CGFloat = 12.0
    public static let cornerRadius: CGFloat = 8.0 // Modern Apple Hybrid
    
    public enum Colors {
        public static let blue = Color(red: 0.0, green: 0.47, blue: 0.84) // Windows 8 Blue
        public static let red = Color(red: 0.89, green: 0.08, blue: 0.05)
        public static let green = Color(red: 0.0, green: 0.64, blue: 0.0)
        public static let orange = Color(red: 1.0, green: 0.34, blue: 0.13)
        public static let purple = Color(red: 0.45, green: 0.11, blue: 0.71)
        public static let cyan = Color(red: 0.11, green: 0.63, blue: 0.89)
        
        // Default set of colors to cycle through
        public static let palette = [blue, red, green, orange, purple, cyan]
        
        public static func color(for string: String) -> Color {
            // Deterministic color assignment based on a string (e.g. Book ID or Title)
            let hash = abs(string.hashValue)
            return palette[hash % palette.count]
        }
    }
}
