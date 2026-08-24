import codecs
import re

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/VisionOCRExtractor.swift', 'r', 'utf-8') as f:
    text = f.read()

target = """        if let match = glicemiaRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange].replacingOccurrences(of: ",", with: ".")) {
            metrics.append(ExtractedMetric(name: "Glicemia (OCR)", value: rawValue, unit: "mg/dL", loincCode: "15074-8", date: now))
        }"""
        
rep = """        if let match = glicemiaRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let valueRange = Range(match.range(at: 1), in: text),
           let rawValue = Double(text[valueRange].replacingOccurrences(of: ",", with: ".")) {
            
            var finalValue = rawValue
            if match.numberOfRanges > 2, let unitRange = Range(match.range(at: 2), in: text) {
                let unitStr = String(text[unitRange]).lowercased()
                if unitStr == "mmol/l" {
                    finalValue = rawValue * 18.0182
                }
            }
            metrics.append(ExtractedMetric(name: "Glicemia (OCR)", value: finalValue, unit: "mg/dL", loincCode: "15074-8", date: now))
        }"""

text = text.replace(target, rep)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/VisionOCRExtractor.swift', 'w', 'utf-8') as f:
    f.write(text)