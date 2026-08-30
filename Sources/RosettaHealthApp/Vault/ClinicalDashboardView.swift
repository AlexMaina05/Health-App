import SwiftUI
import SwiftData
import Charts
import RosettaHealthCore

@available(iOS 26.0, *)
public struct ClinicalDashboardView: View {
    let fiscalCode: String
    
    @Query private var allDocuments: [VaultDocument]
    
    private var patientDocuments: [VaultDocument] {
        allDocuments.filter { $0.fiscalCode == fiscalCode }.sorted { $0.documentDate < $1.documentDate }
    }
    
    public init(fiscalCode: String) {
        self.fiscalCode = fiscalCode
    }
    
    private struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    @State private var dynamicTrends: [(title: String, unit: String, data: [ChartDataPoint])] = []
    @State private var isLoading = true
    
    private func loadTrends() async {
        // Esegue il parsing JSON pesantemente CPU-bound su un background thread
        let docs = patientDocuments
        let trends = await Task.detached { () -> [(title: String, unit: String, data: [ChartDataPoint])] in
            var groups: [String: (title: String, unit: String, data: [ChartDataPoint])] = [:]
            
            for doc in docs {
                guard let data = doc.fhirBundleJSON,
                      let bundle = try? JSONDecoder().decode(FHIRBundle.self, from: data) else { continue }
                
                for entry in bundle.entry {
                    if case .observation(let obs) = entry.resource, let qty = obs.valueQuantity {
                        let code = obs.code.coding.first?.code ?? "unknown"
                        let rawDisplay = obs.code.text ?? obs.code.coding.first?.display ?? "Misurazione"
                        
                        var cleanTitle = rawDisplay
                            .replacingOccurrences(of: " - sangue", with: "", options: .caseInsensitive)
                            .replacingOccurrences(of: "Catalogo Unico SOLE - ", with: "")
                        
                        if let firstDash = cleanTitle.firstIndex(of: "-") {
                            cleanTitle = String(cleanTitle[..<firstDash]).trimmingCharacters(in: .whitespaces)
                        }
                        
                        let point = ChartDataPoint(date: doc.documentDate, value: qty.value)
                        
                        if groups[code] != nil {
                            if !groups[code]!.data.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: doc.documentDate) }) {
                                groups[code]!.data.append(point)
                            }
                        } else {
                            groups[code] = (title: cleanTitle.capitalized, unit: qty.unit, data: [point])
                        }
                    }
                }
            }
            
            return groups.values
                .filter { !$0.data.isEmpty }
                .sorted { 
                    if $0.data.count != $1.data.count { return $0.data.count > $1.data.count }
                    return $0.title < $1.title 
                }
        }.value
        
        await MainActor.run {
            self.dynamicTrends = trends
            self.isLoading = false
        }
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                Text("Trend Clinici Dinamici")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                let trends = dynamicTrends
                
                if isLoading {
                    ProgressView("Analisi serie storiche...")
                        .padding()
                } else if trends.isEmpty {
                    ContentUnavailableView(
                        "Dati Insufficienti",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Nessun parametro clinico quantitativo tracciabile nei referti.")
                    )
                } else {
                    // Limito a 100 per sicurezza prestazioni, anche se LazyVStack gestisce bene
                    ForEach(Array(trends.enumerated()), id: \.offset) { index, trend in
                        metricChart(
                            title: trend.title,
                            data: trend.data,
                            color: chartColor(for: index),
                            unit: trend.unit
                        )
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .task {
            await loadTrends()
        }
    }
    
    private func chartColor(for index: Int) -> Color {
        let colors: [Color] = [.purple, .blue, .orange, .green, .pink, .teal, .indigo, .mint, .cyan]
        return colors[index % colors.count]
    }
    
    @ViewBuilder
    private func metricChart(title: String, data: [ChartDataPoint], color: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            if let latest = data.last {
                Text("\(latest.value, specifier: "%.1f") \(unit)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            
            Chart(data) { point in
                LineMark(
                    x: .value("Data", point.date),
                    y: .value("Valore", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color)
                
                AreaMark(
                    x: .value("Data", point.date),
                    y: .value("Valore", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.opacity(0.1).gradient)
                
                PointMark(
                    x: .value("Data", point.date),
                    y: .value("Valore", point.value)
                )
                .foregroundStyle(color)
            }
            .frame(height: 200)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 3600 * 24 * 365) // 1 anno visibile di default
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }
}
