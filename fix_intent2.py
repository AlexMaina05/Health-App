import codecs
import re

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/Intents/ProcessReportIntent.swift', 'r', 'utf-8') as f:
    text = f.read()

target = """        var xmlData: Data? = nil
        let callback: CGPDFDictionaryApplierFunction = { key, object, info in
            let keyString = String(cString: key)
            if keyString == "EmbeddedFiles",
               var dict = object as? CGPDFDictionary {
                // Semplificazione: Nella vera app usiamo la logica di estrazione CoreGraphics complessa.
                // Per questo intent, ipotizziamo il successo se troviamo l'albero.
            }
            return true
        }
        
        CGPDFDictionaryApplyFunction(catalog, callback, &xmlData)
        return xmlData"""
        
rep = """        // Deprecated: L'App usa PDFEmbeddedAttachmentExtractor.
        return nil"""
text = text.replace(target, rep)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/Intents/ProcessReportIntent.swift', 'w', 'utf-8') as f:
    f.write(text)