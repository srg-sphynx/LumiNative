import SwiftUI

struct Theme {
    // MARK: - Blur Materials
    // Mac Taoho "Liquid Glass" likely refers to highly translucent, blur-heavy UI
    static let backgroundMaterial: NSVisualEffectView.Material = .hudWindow
    static let contentMaterial: Material = .ultraThinMaterial
    
    // MARK: - Colors
    // System colors adapt to Light/Dark mode automatically. 
    // We add some transparency to enhance the glass effect.
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    static let controlBackground = Color.primary.opacity(0.1)
    static let controlHover = Color.primary.opacity(0.2)
    
    static let accentColor = Color.blue // Can be customized
    
    // MARK: - Layout
    static let cornerRadius: CGFloat = 20
    static let padding: CGFloat = 16
    static let elementSpacing: CGFloat = 12
    
    // MARK: - Shadows
    static func applyGlassShadow<Content: View>(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

// Extension to easily apply the Liquid Glass background to any view
extension View {
    func liquidGlassBackground() -> some View {
        self
            .glassBackground(material: Theme.backgroundMaterial)
            .cornerRadius(Theme.cornerRadius)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(LinearGradient(gradient: Gradient(colors: [.white.opacity(0.4), .white.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
    
    func glassElement() -> some View {
        self
            .background(Theme.contentMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}
