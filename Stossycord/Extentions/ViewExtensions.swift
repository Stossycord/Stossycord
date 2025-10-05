import SwiftUI

struct GlassEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .blur(radius: 10)
            .opacity(0.7)
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
    }
}

extension View {
    func glassEffect() -> some View {
        self.modifier(GlassEffect())
    }
}