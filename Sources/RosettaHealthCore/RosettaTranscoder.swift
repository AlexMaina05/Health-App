import Foundation

public final class RosettaTranscoder: NSObject, XMLParserDelegate {
    private var parser: XMLParser?
    private var parseError: Error?
    
    // Extracted Entities
    private var isClinicalDocument = false
    private var documentId: String?
    private var patientFiscalCode: String?
    private var patientFamilyName: String?
    private var patientGivenName: String?
    private var docTitle: String = "Referto Sanitario FSE"
    private var docDate: String = ""
    
    private var observations: [FHIRObservation] = []
    
    // State Tracking
    private var currentPath: [String] = []
    private var insideObservation = false
    private var currentObsCode: FHIRCodeableConcept?
    private var currentObsValue: FHIRQuantity?
    private var currentObsValueString: String?
    private var currentObsEffectiveTime: String = ""
    private var currentRangeLow: Double?
    private var currentRangeHigh: Double?
    private var currentElementData: String = ""
    private var currentRangeUnit: String = ""
    private var currentRangeText: String = ""
    private var accumulatedNarrativeText: String = ""
    
    public func transcode(cdaData: Data) throws -> FHIRBundle {
        self.observations.removeAll()
        self.accumulatedNarrativeText = ""
        self.currentPath.removeAll()
        self.isClinicalDocument = false
        self.documentId = nil
        self.patientFiscalCode = nil
        self.patientFamilyName = nil
        self.patientGivenName = nil
        self.docTitle = "Referto Sanitario FSE"
        self.docDate = ""
        self.parseError = nil
        
        self.parser = XMLParser(data: cdaData)
        self.parser?.delegate = self
        self.parser?.shouldResolveExternalEntities = false // Protezione critica contro attacchi XXE e XML Bombs (Billion Laughs)
        
        guard let p = self.parser, p.parse() else {
            if let err = parseError {
                throw RosettaError.malformedXML(underlying: err.localizedDescription)
            } else if let pErr = p.parserError {
                throw RosettaError.malformedXML(underlying: pErr.localizedDescription)
            } else {
                throw RosettaError.malformedXML(underlying: "Errore sconosciuto nel parsing SAX.")
            }
        }
        
        guard isClinicalDocument else {
            throw RosettaError.missingClinicalDocumentHeader
        }
        
        // Se ci sono nodi narrativi ma nessuna observation, logghiamo semplicemente senza crasciare
        if observations.isEmpty {
            // Nota: L'utente richiede di non lanciare un fatal error, ma solo gestirlo.
            // Possiamo emettere un print o proseguire, il bundle sarà composto dalla sola Composition.
            // Log rimosso per privacy e pulizia trovata nel referto.")
        }
        
        let patientId = "patient-fse-subject"
        let patientResource = FHIRPatient(
            id: patientId,
            identifier: patientFiscalCode.map { [FHIRIdentifier(system: "http://hl7.it/sid/codiceFiscale", value: $0)] },
            name: [FHIRHumanName(family: patientFamilyName, given: patientGivenName.map { [$0] })],
            gender: nil,
            birthDate: nil
        )
        
        let narrativeText = accumulatedNarrativeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let compositionNarrative: FHIRNarrative? = narrativeText.isEmpty ? nil : FHIRNarrative(div: narrativeText)
        
        let compositionResource = FHIRComposition(
            id: UUID().uuidString,
            type: FHIRCodeableConcept(coding: [FHIRCoding(system: "http://loinc.org", code: "11502-2", display: "Laboratory report")]),
            subject: FHIRReference(reference: "Patient/\(patientId)", display: "\(patientFamilyName ?? "") \(patientGivenName ?? "")".trimmingCharacters(in: .whitespaces)),
            date: docDate.isEmpty ? ISO8601DateFormatter().string(from: Date()) : docDate,
            title: docTitle,
            text: compositionNarrative
        )
        
        var bundleEntries: [FHIRBundleEntry] = [
            FHIRBundleEntry(fullUrl: "urn:uuid:\(compositionResource.id)", resource: .composition(compositionResource)),
            FHIRBundleEntry(fullUrl: "urn:uuid:\(patientId)", resource: .patient(patientResource))
        ]
        
        for obs in observations {
            bundleEntries.append(FHIRBundleEntry(fullUrl: "urn:uuid:\(obs.id)", resource: .observation(obs)))
        }
        
        return FHIRBundle(
            id: documentId ?? UUID().uuidString,
            type: "document",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            entry: bundleEntries
        )
    }
    
    // MARK: - XMLParser Delegate Implementation
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentPath.append(elementName)
        currentElementData = ""
        
        if elementName == "ClinicalDocument" {
            isClinicalDocument = true
        }
        
        if elementName == "id" && currentPath == ["ClinicalDocument", "id"] {
            documentId = attributeDict["extension"] ?? attributeDict["root"]
        }
        
        // 1. Patient Fiscal Code
        if elementName == "id" && currentPath.contains("patientRole") {
            if attributeDict["root"] == "2.16.840.1.113883.2.9.4.3.2" || attributeDict["root"] == "2.16.840.1.113883.2.9.2.130.4.1" {
                patientFiscalCode = attributeDict["extension"]
            }
        }
        
        // 2. Document Title & Effective Time
        if elementName == "effectiveTime" && currentPath.contains("ClinicalDocument") && !currentPath.contains("component") {
            if let val = attributeDict["value"] {
                docDate = normalizeCDADate(val)
            }
        }
        
        // 3. Observation Parsing
        if elementName == "observation" && attributeDict["classCode"] == "OBS" {
            insideObservation = true
            currentObsCode = nil
            currentObsValue = nil
            currentObsValueString = nil
            currentObsEffectiveTime = docDate
            currentRangeLow = nil
            currentRangeHigh = nil
            currentRangeUnit = ""
            currentRangeText = ""
        }
        
        guard insideObservation else { return }
        
        if elementName == "code" {
            if let code = attributeDict["code"], let codeSystem = attributeDict["codeSystem"] {
                let display = attributeDict["displayName"]
                let systemUri = mapOIDToSystem(codeSystem)
                currentObsCode = FHIRCodeableConcept(coding: [FHIRCoding(system: systemUri, code: code, display: display)], text: display)
            } else if let display = attributeDict["displayName"] {
                currentObsCode = FHIRCodeableConcept(coding: [], text: display)
            }
        }
        
        if elementName == "effectiveTime", let val = attributeDict["value"] {
            currentObsEffectiveTime = normalizeCDADate(val)
        }
        
        if elementName == "value" {
            let type = attributeDict["xsi:type"] ?? ""
            if type == "PQ" || type == "REAL" || type == "INT" {
                if let rawValStr = attributeDict["value"] {
                    let normalized = rawValStr.replacingOccurrences(of: ",", with: ".")
                    let unit = attributeDict["unit"] ?? ""
                    if let dVal = Double(normalized) {
                        let quantityUnit = unit.isEmpty ? "1" : unit
                        currentObsValue = FHIRQuantity(value: dVal, unit: quantityUnit, code: quantityUnit)
                    } else {
                        // Fallback: preserve unparsed measurement string with unit
                        if !unit.isEmpty && unit != "1" {
                            currentObsValueString = "\(rawValStr) \(unit)"
                        } else {
                            currentObsValueString = rawValStr
                        }
                    }
                }
            } else if type == "ST" || type == "TX" {
                currentObsValueString = attributeDict["value"]
            } else {
                if let rawValStr = attributeDict["value"] {
                    let normalized = rawValStr.replacingOccurrences(of: ",", with: ".")
                    let unit = attributeDict["unit"] ?? ""
                    if let dVal = Double(normalized) {
                        let quantityUnit = unit.isEmpty ? "1" : unit
                        currentObsValue = FHIRQuantity(value: dVal, unit: quantityUnit, code: quantityUnit)
                    } else {
                        if !unit.isEmpty && unit != "1" {
                            currentObsValueString = "\(rawValStr) \(unit)"
                        } else {
                            currentObsValueString = rawValStr
                        }
                    }
                }
            }
        }
        
        if elementName == "low", let valStr = attributeDict["value"] {
            let normalized = valStr.replacingOccurrences(of: ",", with: ".")
            currentRangeLow = Double(normalized)
            currentRangeUnit = attributeDict["unit"] ?? ""
        }
        
        if elementName == "high", let valStr = attributeDict["value"] {
            let normalized = valStr.replacingOccurrences(of: ",", with: ".")
            currentRangeHigh = Double(normalized)
            if currentRangeUnit.isEmpty { currentRangeUnit = attributeDict["unit"] ?? "" }
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentElementData += string
        
        // Se siamo dentro una sezione narrativa, accumuliamo il testo pulito
        if currentPath.contains("section") && currentPath.contains("text") {
            let cleanStr = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanStr.isEmpty {
                accumulatedNarrativeText += cleanStr + " "
            }
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentElementData.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if elementName == "family" && currentPath.contains("patient") {
            patientFamilyName = trimmed
        } else if elementName == "given" && currentPath.contains("patient") {
            patientGivenName = trimmed
        }
        
        if elementName == "originalText" && currentPath.contains("code") {
            if currentObsCode == nil && !trimmed.isEmpty {
                currentObsCode = FHIRCodeableConcept(coding: [], text: trimmed)
            }
        }
        
        if elementName == "code" && insideObservation {
            if currentObsCode == nil && !trimmed.isEmpty {
                currentObsCode = FHIRCodeableConcept(coding: [], text: trimmed)
            }
        }
        
        if elementName == "value" && insideObservation {
            if currentObsValue == nil && (currentObsValueString == nil || currentObsValueString?.isEmpty == true) {
                if !trimmed.isEmpty {
                    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                    if let dVal = Double(normalized) {
                        currentObsValue = FHIRQuantity(value: dVal, unit: "1", code: "1")
                    } else {
                        currentObsValueString = trimmed
                    }
                }
            }
        }
        
        if elementName == "observation" && insideObservation {
            let code = currentObsCode ?? FHIRCodeableConcept(coding: [], text: "Observation")
            var ranges: [FHIRReferenceRange]? = nil
            if currentRangeLow != nil || currentRangeHigh != nil || !currentRangeText.isEmpty {
                let lowQty = currentRangeLow.map { FHIRSimpleQuantity(value: $0, unit: currentRangeUnit) }
                let highQty = currentRangeHigh.map { FHIRSimpleQuantity(value: $0, unit: currentRangeUnit) }
                ranges = [FHIRReferenceRange(low: lowQty, high: highQty, text: currentRangeText.isEmpty ? nil : currentRangeText)]
            }
            
            let obs = FHIRObservation(
                id: UUID().uuidString,
                status: "final",
                category: [FHIRCodeableConcept(coding: [FHIRCoding(system: "http://terminology.hl7.org/CodeSystem/observation-category", code: "laboratory", display: "Laboratory")])],
                code: code,
                subject: FHIRReference(reference: "Patient/patient-fse-subject", display: "Intestatario FSE"),
                effectiveDateTime: currentObsEffectiveTime.isEmpty ? (docDate.isEmpty ? ISO8601DateFormatter().string(from: Date()) : docDate) : currentObsEffectiveTime,
                valueQuantity: currentObsValue,
                valueString: currentObsValueString,
                referenceRange: ranges
            )
            observations.append(obs)
            insideObservation = false
        }
        
        if !currentPath.isEmpty {
            currentPath.removeLast()
        }
    }
    
    private func mapOIDToSystem(_ oid: String) -> String {
        switch oid {
        case "2.16.840.1.113883.6.1": return "http://loinc.org"
        case "2.16.840.1.113883.6.96": return "http://snomed.info/sct"
        case "2.16.840.1.113883.6.8": return "http://unitsofmeasure.org"
        case "2.16.840.1.113883.2.9.4.3.2": return "http://hl7.it/sid/codiceFiscale"
        default: return "urn:oid:\(oid)"
        }
    }
    
    private func normalizeCDADate(_ raw: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var dateString = raw
        if raw.count >= 14 {
            formatter.dateFormat = "yyyyMMddHHmmss"
            dateString = String(raw.prefix(14))
        } else if raw.count >= 8 {
            formatter.dateFormat = "yyyyMMdd"
            dateString = String(raw.prefix(8))
        } else {
            return raw
        }
        if let d = formatter.date(from: dateString) {
            return ISO8601DateFormatter().string(from: d)
        }
        return raw
    }
}
