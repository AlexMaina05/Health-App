import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable {
    case blue = "Blu (Predefinito)"
    case purple = "Viola"
    case teal = "Ottanio"
    case green = "Verde Salute"
    case red = "Rosso Cardio"
    
    public var id: String { self.rawValue }
    
    public var color: Color {
        switch self {
        case .purple: return .purple
        case .blue: return .blue
        case .teal: return .teal
        case .green: return .green
        case .red: return .red
        }
    }
}