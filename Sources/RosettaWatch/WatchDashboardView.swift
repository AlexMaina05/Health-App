import SwiftUI
import HealthKit

#if os(watchOS)
@available(watchOS 10.0, *)
public struct WatchDashboardView: View {
    // Leggiamo dall'App Group condiviso (stesso meccanismo dei Widget)
    @AppStorage("latestMetricValue", store: UserDefaults(suiteName: "group.dev.alexmaina.rosettahealth"))
    private var latestMetricValue: Double = 0.0
    
    @AppStorage("latestMetricName", store: UserDefaults(suiteName: "group.dev.alexmaina.rosettahealth"))
    private var latestMetricName: String = "Nessun Dato"
    
    @AppStorage("latestMetricUnit", store: UserDefaults(suiteName: "group.dev.alexmaina.rosettahealth"))
    private var latestMetricUnit: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    Gauge(value: latestMetricValue, in: 0...200) {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(.purple)
                    } currentValueLabel: {
                        Text("\(latestMetricValue, specifier: "%.0f")")
                            .foregroundColor(.purple)
                    } minimumValueLabel: {
                        Text("0")
                            .foregroundColor(.green)
                    } maximumValueLabel: {
                        Text("200")
                            .foregroundColor(.red)
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
                        .foregroundColor(.secondary)
                    
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
            .navigationTitle("RosettaHealth")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
