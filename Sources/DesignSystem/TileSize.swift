import CoreGraphics

public enum TileSize {
    case small   // e.g. 1x1
    case medium  // e.g. 2x2
    case wide    // e.g. 4x2
    case large   // e.g. 4x4
    
    // Returns the relative aspect ratio based on a base unit grid
    public var aspectRatio: CGFloat {
        switch self {
        case .small:  return 1.0     // 1:1
        case .medium: return 1.0     // 1:1
        case .wide:   return 2.0     // 2:1 (width:height)
        case .large:  return 1.0     // 1:1
        }
    }
    
    // Defines how many grid columns this tile spans
    public var columnSpan: Int {
        switch self {
        case .small:  return 1
        case .medium: return 2
        case .wide:   return 4
        case .large:  return 4
        }
    }
}
