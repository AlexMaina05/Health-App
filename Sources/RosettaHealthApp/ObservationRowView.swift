import SwiftUI
import Charts
import RosettaHealthCore

struct ObservationRowView: View {
    let observation: FHIRObservation
    
    @State private var history: [(date: Date, value: Double)] = []
    @State private var selectedDate: Date?
    
    // Logica di valutazione Range
    private var isOutOfRange: Bool {
        guard let qty = observation.valueQuantity?.value,
              let ranges = observation.referenceRange, let range = ranges.first else {
            return false
        }
        if let low = range.low?.value, qty < low { return true }
        if let high = range.high?.value, qty > high { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                // Icona laterale
                ZStack {
                    Circle()
                        .fill(isOutOfRange ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: isOutOfRange ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                        .foregroundStyle(isOutOfRange ? .red : .blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(observation.code.text ?? observation.code.coding.first?.display ?? "Parametro Sconosciuto")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    if let ranges = observation.referenceRange, let range = ranges.first {
                        if let low = range.low?.value, let high = range.high?.value {
                            Text("Range: \(String(format: "%.1f", low)) - \(String(format: "%.1f", high))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if let qty = observation.valueQuantity {
                        Text(String(format: "%.2f", qty.value))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(isOutOfRange ? .red : .primary)
                        Text(qty.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    } else if let str = observation.valueString {
                        Text(str)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            
            // Mini-Grafico (Sparkline)
            if history.count > 1 {
                Chart {
                    ForEach(history, id: \.date) { point in
                        LineMark(
                            x: .value("Data", point.date),
                            y: .value("Valore", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(isOutOfRange ? Color.red.gradient : Color.blue.gradient)
                        
                        PointMark(
                            x: .value("Data", point.date),
                            y: .value("Valore", point.value)
                        )
                        .foregroundStyle(isOutOfRange ? Color.red : Color.blue)
                    }
                }
                .frame(height: 50)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(observation.code.text ?? observation.code.coding.first?.display ?? "Parametro"))
        .accessibilityValue(Text("\(observation.valueQuantity?.value ?? 0) \(observation.valueQuantity?.unit ?? "")"))
        .accessibilityHint(isOutOfRange ? Text("Valore fuori dalla norma") : Text("Valore nella norma"))
        .task {
            await loadHistory()
        }
    }
    
    private func loadHistory() async {
        guard let loinc = observation.code.coding.first?.code else { return }
        let bridge = HealthKitBridge.shared
        guard let target = bridge.loincToHKMap[loinc] else { return }
        
        if let samples = try? await bridge.fetchHistoricalSamples(for: target.type, limit: 5) {
            let points = samples.map { (date: $0.startDate, value: $0.quantity.doubleValue(for: target.defaultUnit)) }
            self.history = points.sorted { $0.date < $1.date }
        }
    }
}