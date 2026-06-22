import SwiftUI

/// A ButtonStyle that replicates the classic Windows Phone "squish" or "tilt" effect.
public struct MetroTileButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            // A subtle 3D rotation could be added here for the "tilt",
            // but pure scale is generally safer and cleaner on modern devices.
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

/// A generic, reusable Metro Tile container.
public struct MetroTile<Content: View>: View {
    let size: TileSize
    let backgroundColor: Color
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    
    public init(
        size: TileSize = .medium,
        backgroundColor: Color = MetroTheme.Colors.blue,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.action = action
        self.content = content
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Background
                backgroundColor
                
                // Content
                content()
                    .padding(MetroTheme.spacing)
            }
            // Enforce aspect ratio based on the tile size
            .aspectRatio(size.aspectRatio, contentMode: .fill)
            // Apply standardized corner radius
            .clipShape(RoundedRectangle(cornerRadius: MetroTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(MetroTileButtonStyle())
    }
}
