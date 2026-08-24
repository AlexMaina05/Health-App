import SwiftUI

public extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
#if compiler(>=8.0)
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.fallbackGlass(cornerRadius: cornerRadius)
        }
#else
        self.fallbackGlass(cornerRadius: cornerRadius)
#endif
    }
    
    private func fallbackGlass(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .blendMode(.overlay)
            )
    }
}