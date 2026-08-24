import SwiftUI

public extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        // Avendo aggiornato il target minimo a iOS 26, possiamo usare l'API nativa
        self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    }
}