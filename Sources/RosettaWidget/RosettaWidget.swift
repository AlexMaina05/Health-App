import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), metricName: "Glicemia", metricValue: "95 mg/dL")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), metricName: "Glicemia", metricValue: "95 mg/dL")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Leggiamo dall'App Group condiviso! Zero-Cloud e Zero-HealthKit Lock
        let sharedDefaults = UserDefaults(suiteName: "group.dev.alexmaina.rosettahealth")
        let name = sharedDefaults?.string(forKey: "widget_metricName") ?? "Nessun referto"
        let value = sharedDefaults?.string(forKey: "widget_metricValue") ?? "--"
        
        let entry = SimpleEntry(date: Date(), metricName: name, metricValue: value)
        
        // Aggiorna il widget (in questo caso la timeline è statica fino a nuovo referto)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let metricName: String
    let metricValue: String
}

struct RosettaWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.blue)
                Text("RosettaHealth")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            
            Text(entry.metricName)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Text(entry.metricValue)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding()
        // Gradiente premium per allinearsi alla main app
        .background(
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

struct RosettaWidgetMain: Widget {
    let kind: String = "RosettaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                RosettaWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                RosettaWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Ultimo Referto")
        .description("Visualizza l'ultimo parametro clinico analizzato da RosettaHealth.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct RosettaWidgetBundle: WidgetBundle {
    var body: some Widget {
        RosettaWidgetMain()
        if #available(iOS 16.1, *) {
            RosettaParsingLiveActivity()
        }
    }
}
