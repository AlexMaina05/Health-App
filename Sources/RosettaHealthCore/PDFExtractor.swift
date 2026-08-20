import Foundation
import PDFKit

public enum ExtractionResult {
    case cdaXML(Data)
    case rasterOCR([ExtractedMetric])
}

public final class PDFEmbeddedAttachmentExtractor {
    public static func extract(from url: URL) async throws -> ExtractionResult {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw RosettaError.pdfCorrupted
        }
        
        if let xmlData = try? extractXML(from: document) {
            return .cdaXML(xmlData)
        }
        
        let metrics = try await VisionOCRExtractor.extractMetricsFromRasterPDF(url: url)
        if metrics.isEmpty {
            throw RosettaError.noEmbeddedXMLFound
        }
        
        return .rasterOCR(metrics)
    }

    public static func extractXML(from url: URL) throws -> Data {
        guard let document = CGPDFDocument(url as CFURL) else {
            throw RosettaError.pdfCorrupted
        }
        return try extractXML(from: document)
    }

    private static func extractXML(from document: CGPDFDocument) throws -> Data {
        guard let catalog = document.catalog else {
            throw RosettaError.noEmbeddedXMLFound
        }
        
        var namesDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(catalog, "Names", &namesDict),
              let names = namesDict else {
            throw RosettaError.noEmbeddedXMLFound
        }
        
        var embeddedFilesDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(names, "EmbeddedFiles", &embeddedFilesDict),
              let embeddedFiles = embeddedFilesDict else {
            throw RosettaError.noEmbeddedXMLFound
        }
        
        var namesArray: CGPDFArrayRef?
        if CGPDFDictionaryGetArray(embeddedFiles, "Names", &namesArray), let array = namesArray {
            let count = CGPDFArrayGetCount(array)
            for i in stride(from: 0, to: count, by: 2) {
                var fileSpecDict: CGPDFDictionaryRef?
                if CGPDFArrayGetDictionary(array, i + 1, &fileSpecDict), let spec = fileSpecDict {
                    if let xmlData = extractEFStream(from: spec) {
                        return xmlData
                    }
                }
            }
        }
        
        throw RosettaError.noEmbeddedXMLFound
    }
    
    private static func extractEFStream(from fileSpec: CGPDFDictionaryRef) -> Data? {
        var efDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(fileSpec, "EF", &efDict), let ef = efDict else {
            return nil
        }
        
        var stream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(ef, "F", &stream), let streamRef = stream else {
            return nil
        }
        
        var format: CGPDFDataFormat = .raw
        guard let dataRef = CGPDFStreamCopyData(streamRef, &format) else {
            return nil
        }
        
        return dataRef as Data
    }
}
