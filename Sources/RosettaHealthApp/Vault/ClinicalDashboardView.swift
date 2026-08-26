import SwiftUI
import SwiftData
import Charts
import RosettaHealthCore

@available(iOS 26.0, *)
public struct ClinicalDashboardView: View {
    let fiscalCode: String
    
    @Query private var allDocuments: [VaultDocument]
    
    // Filtriamo i documenti del paziente
    private var patientDocuments: [VaultDocument] {
        allDocuments.filter { $0.fiscalCode == fiscalCode }.sorted { $0.documentDate < $1.documentDate }
    }
    
    public init(fiscalCode: String) {
        self.fiscalCode = fiscalCode
    }
    
    // Estrae una specifica misurazione (es. LOINC code) da un documento
    private func extractMetric(from document: VaultDocument, loincCode: String) -> Double? {
        guard let data = document.fhirBundleJSON,
              let bundle = try? JSONDecoder().decode(FHIRBundle.self, from: data) else { return nil }
        
        for entry in bundle.entry {
            if case .observation(let obs) = entry.resource {
                let hasCode = obs.code.coding.contains { $0.code == loincCode }
                if hasCode, let value = obs.valueQuantity?.value {
                    return value
                }
            }
        }
        return nil
    }
    
    // Generiamo i dati per i grafici
    private struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    private func getTrend(loincCode: String) -> [ChartDataPoint] {
        patientDocuments.compactMap { doc in
            if let val = extractMetric(from: doc, loincCode: loincCode) {
                return ChartDataPoint(date: doc.documentDate, value: val)
            }
            return nil
        }
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Trend Clinici")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Emoglobina Glicata (LOINC 4548-4)
                let hba1cTrend = getTrend(loincCode: "4548-4")
                if !hba1cTrend.isEmpty {
                    metricChart(title: "Emoglobina Glicata (HbA1c)", data: hba1cTrend, color: .purple, unit: "%")
                }
                
                // Colesterolo Totale (LOINC 2093-3)
                let cholTrend = getTrend(loincCode: "2093-3")
                if !cholTrend.isEmpty {
                    metricChart(title: "Colesterolo Totale", data: cholTrend, color: .orange, unit: "mg/dL")
                }
                
                // Glicemia a digiuno (LOINC 14771-0)
                let glucoseTrend = getTrend(loincCode: "14771-0")
                if !glucoseTrend.isEmpty {
                    metricChart(title: "Glicemia a digiuno", data: glucoseTrend, color: .blue, unit: "mg/dL")
                }
                
                if hba1cTrend.isEmpty && cholTrend.isEmpty && glucoseTrend.isEmpty {
                    ContentUnavailableView(
                        "Dati Insufficienti",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Nessun parametro clinico tracciabile nei referti di questo paziente.")
                    )
                }
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
            .chartXVisibleDomain(length: 3600 * 24 * 180) // 6 mesi visibili di default
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }
}