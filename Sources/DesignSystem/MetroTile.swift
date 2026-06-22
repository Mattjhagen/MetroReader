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
    let state: MetroTileState
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    
    public init(
        size: TileSize = .medium,
        backgroundColor: Color = MetroTheme.Colors.blue,
        state: MetroTileState = .normal,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.state = state
        self.action = action
        self.content = content
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Background
                if state == .missing {
                    Color.clear
                } else if state == .corrupted {
                    backgroundColor.grayscale(0.8).opacity(0.6)
                } else if state == .incomplete {
                    backgroundColor.opacity(0.6)
                } else {
                    backgroundColor
                }
                
                // Fractured Noise Overlay for Corrupted
                if state == .corrupted {
                    Stripes(config: .default)
                        .stroke(Color.black.opacity(0.3), lineWidth: 2)
                }
                
                // Content
                content()
                    .padding(MetroTheme.spacing)
                    .opacity(state == .missing ? 0.5 : 1.0)
            }
            // Enforce aspect ratio based on the tile size
            .aspectRatio(size.aspectRatio, contentMode: .fill)
            // Apply standardized corner radius
            .clipShape(RoundedRectangle(cornerRadius: MetroTheme.cornerRadius, style: .continuous))
            // Borders
            .overlay(
                RoundedRectangle(cornerRadius: MetroTheme.cornerRadius, style: .continuous)
                    .strokeBorder(
                        state == .missing ? Color.gray.opacity(0.5) : (state == .corrupted ? Color.gray.opacity(0.8) : Color.clear),
                        style: StrokeStyle(lineWidth: 2, dash: state == .missing ? [10, 5] : [])
                    )
            )
        }
        .buttonStyle(MetroTileButtonStyle())
    }
}

public enum MetroTileState {
    case normal
    case missing
    case corrupted
    case incomplete
}

// Simple striped pattern for the corrupted state
public struct Stripes: Shape {
    public struct Config: Sendable {
        public var spacing: CGFloat
        public var angle: Angle
        public static let `default` = Config(spacing: 15, angle: .degrees(45))
        
        public init(spacing: CGFloat, angle: Angle) {
            self.spacing = spacing
            self.angle = angle
        }
    }
    public let config: Config
    
    public init(config: Config) {
        self.config = config
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let diagonal = sqrt(width * width + height * height)
        let lines = Int(diagonal / config.spacing)
        
        for i in 0...lines {
            let offset = CGFloat(i) * config.spacing
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset - height, y: height))
        }
        return path
    }
}
