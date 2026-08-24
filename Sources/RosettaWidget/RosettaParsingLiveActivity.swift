import WidgetKit
import SwiftUI
import ActivityKit
import RosettaHealthCore

@available(iOS 16.1, *)
struct RosettaParsingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParsingAttributes.self) { context in
            // Lock screen / banner UI
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "scanner")
                        .foregroundStyle(.purple)
                    Text(context.attributes.batchName)
                        .font(.headline)
                    Spacer()
                    Text("\(context.state.processedFiles)/\(context.state.totalFiles)")
                        .fontWeight(.bold)
                }
                
                ProgressView(value: Double(context.state.processedFiles), total: Double(context.state.totalFiles))
                    .tint(.purple)
                
                Text(context.state.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "doc.viewfinder")
                        .foregroundStyle(.purple)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.processedFiles)/\(context.state.totalFiles)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: Double(context.state.processedFiles), total: Double(context.state.totalFiles))
                        .tint(.purple)
                    Text(context.state.statusText)
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "doc.viewfinder")
                    .foregroundStyle(.purple)
            } compactTrailing: {
                Text("\(context.state.processedFiles)/\(context.state.totalFiles)")
            } minimal: {
                Image(systemName: "doc.viewfinder")
                    .foregroundStyle(.purple)
            }
        }
    }
}
