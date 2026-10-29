import SwiftUI
import HealthKit

#if os(watchOS)
@available(watchOS 10.0, *)
public struct WatchDashboardView: View {
    // Leggiamo dall'App Group condiviso (stesso meccanismo dei Widget)
    @AppStorage("latestMetricValue", store: UserDefaults(suiteName: "group.dev.alexmaina.rosettaedge"))
    private var latestMetricValue: Double = 0.0
    
    @AppStorage("latestMetricName", store: UserDefaults(suiteName: "group.dev.alexmaina.rosettaedge"))
    private var latestMetricName: String = "Nessun Dato"
    
    @AppStorage("latestMetricUnit", store: UserDefaults(suiteName: "group.dev.alexmaina.rosettaedge"))
    private var latestMetricUnit: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    Gauge(value: latestMetricValue, in: 0...200) {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(.purple)
                    } currentValueLabel: {
                        Text("\(latestMetricValue, specifier: "%.0f")")
                            .foregroundStyle(.purple)
                    } minimumValueLabel: {
                        Text("0")
                            .foregroundStyle(.green)
                    } maximumValueLabel: {
                        Text("200")
                            .foregroundStyle(.red)
                    }
                    .gaugeStyle(.circular)
                    .tint(Gradient(colors: [.green, .yellow, .red]))
                    .scaleEffect(1.2)
                    .padding(.vertical, 8)
                    
                    Text(latestMetricName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Text(latestMetricUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Button(action: {
                        // In un'app reale, questo scatenerebbe un WCSession message all'iPhone
                    }) {
                        Label("Sincronizza", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.purple)
                }
                .padding()
            }
            .navigationTitle("RosettaEdge")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
