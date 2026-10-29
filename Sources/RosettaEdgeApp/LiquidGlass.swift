import SwiftUI

public extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat? = nil) -> some View {
        if let radius = cornerRadius {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: ContainerRelativeShape())
        }
    }
}