import Foundation
import PDFKit
import Vision
import UIKit

public struct ExtractedMetric: Sendable {
    public let name: String
    public let value: Double
    public let unit: String
    public let loincCode: String
    public let date: Date
    
    public init(name: String, value: Double, unit: String, loincCode: String, date: Date = Date()) {
        self.name = name
        self.value = value
        self.unit = unit
        self.loincCode = loincCode
        self.date = date
    }
}

public final class VisionOCRExtractor {
    
    public static func extractMetricsFromRasterPDF(url: URL) async throws -> [ExtractedMetric] {
        return try await Task.detached(priority: .userInitiated) {
            guard let pdfDocument = PDFDocument(url: url) else {
                throw RosettaError.pdfCorrupted
            }
            
            var recognizedText = ""
            
            // Render pagine ed esecuzione OCR fuori dal Main Thread
            for i in 0..<pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: i) else { continue }
                let rect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: rect.size)
                let image = renderer.image { ctx in
                    UIColor.white.set()
                    ctx.fill(rect)
                    ctx.cgContext.translateBy(x: 0.0, y: rect.size.height)
                    ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                
                guard let cgImage = image.cgImage else { continue }
                
                let text = try performOCR(on: cgImage)
                recognizedText += text + "\n"
            }
            
            return parseMetrics(from: recognizedText)
        }.value
    }
    
    private static func performOCR(on cgImage: CGImage) throws -> String {
        var recognizedText = ""
        var visionError: Error?
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                visionError = error
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["it-IT", "en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        if let error = visionError {
            throw error
        }
        
        return recognizedText
    }
    
    private static func parseMetrics(from text: String) -> [ExtractedMetric] {
        var metrics: [ExtractedMetric] = []
        let now = Date()
        
        // 1. Glicemia / Glucosio
        let glicemiaRegex = try? NSRegularExpression(pattern: #"(?i)(?:glicemia|glucosio)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(mg\/dl|mmol\/l)?"#)
        if let match = glicemiaRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange].replacingOccurrences(of: ",", with: ".")) {
            metrics.append(ExtractedMetric(name: "Glicemia (OCR)", value: rawValue, unit: "mg/dL", loincCode: "15074-8", date: now))
        }
        
        // 2. Colesterolo Totale
        let colesteroloRegex = try? NSRegularExpression(pattern: #"(?i)(?:colesterolo\s+totale|colesterolo)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(mg\/dl)?"#)
        if let match = colesteroloRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange].replacingOccurrences(of: ",", with: ".")) {
            metrics.append(ExtractedMetric(name: "Colesterolo Totale (OCR)", value: rawValue, unit: "mg/dL", loincCode: "2093-3", date: now))
        }
        
        // 3. Colesterolo HDL
        let hdlRegex = try? NSRegularExpression(pattern: #"(?i)(?:colesterolo\s+hdl|hdl)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(mg\/dl)?"#)
        if let match = hdlRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange].replacingOccurrences(of: ",", with: ".")) {
            metrics.append(ExtractedMetric(name: "Colesterolo HDL (OCR)", value: rawValue, unit: "mg/dL", loincCode: "2085-9", date: now))
        }
        
        // 4. Trigliceridi
        let trigliceridiRegex = try? NSRegularExpression(pattern: #"(?i)(?:trigliceridi)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(mg\/dl)?"#)
        if let match = trigliceridiRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange].replacingOccurrences(of: ",", with: ".")) {
            metrics.append(ExtractedMetric(name: "Trigliceridi (OCR)", value: rawValue, unit: "mg/dL", loincCode: "2571-8", date: now))
        }
        
        // 5. Frequenza Cardiaca
        let fcRegex = try? NSRegularExpression(pattern: #"(?i)(?:frequenza\s+cardiaca|battito|f\.?c\.?)\s*[:=]?\s*(\d+)\s*(?:bpm|battiti|min)?"#)
        if let match = fcRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange]) {
            metrics.append(ExtractedMetric(name: "Frequenza Cardiaca (OCR)", value: rawValue, unit: "count/min", loincCode: "8867-4", date: now))
        }
        
        // 6. Pressione Arteriosa (Sistolica / Diastolica)
        let paRegex = try? NSRegularExpression(pattern: #"(?i)(?:pressione|p\.?a\.?)\s*[:=]?\s*(\d{2,3})\s*[\/\-]\s*(\d{2,3})\s*(?:mmhg)?"#)
        if let match = paRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let sysRange = Range(match.range(at: 1), in: text),
           let diaRange = Range(match.range(at: 2), in: text),
           let sysValue = Double(text[sysRange]),
           let diaValue = Double(text[diaRange]) {
            metrics.append(ExtractedMetric(name: "Pressione Sistolica (OCR)", value: sysValue, unit: "mmHg", loincCode: "8480-6", date: now))
            metrics.append(ExtractedMetric(name: "Pressione Diastolica (OCR)", value: diaValue, unit: "mmHg", loincCode: "8462-4", date: now))
        }
        
        return metrics
    }
}
