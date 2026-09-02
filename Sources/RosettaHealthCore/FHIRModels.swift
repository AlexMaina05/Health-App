import Foundation

public struct FHIRMeta: Codable {
    public let profile: [String]
    public init(profile: [String]) {
        self.profile = profile
    }
}

public struct FHIRBundle: Codable {
    public var resourceType: String = "Bundle"
    public let id: String
    public let meta: FHIRMeta?
    public let identifier: FHIRIdentifier?
    public let type: String // "document" or "collection"
    public let timestamp: String
    public let entry: [FHIRBundleEntry]
    
    public init(id: String = UUID().uuidString, type: String = "document", timestamp: String, entry: [FHIRBundleEntry], identifier: FHIRIdentifier? = nil) {
        self.id = id
        // Iniezione Profilo IPS (International Patient Summary)
        self.meta = FHIRMeta(profile: ["http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips"])
        self.type = type
        self.timestamp = timestamp
        self.entry = entry
        self.identifier = identifier
    }
}

public struct FHIRBundleEntry: Codable {
    public let fullUrl: String?
    public let resource: FHIRResource
    
    public init(fullUrl: String? = nil, resource: FHIRResource) {
        self.fullUrl = fullUrl
        self.resource = resource
    }
}

public enum FHIRResource: Codable {
    case observation(FHIRObservation)
    case patient(FHIRPatient)
    case composition(FHIRComposition)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .observation(let obs): try container.encode(obs)
        case .patient(let pat): try container.encode(pat)
        case .composition(let comp): try container.encode(comp)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let obs = try? container.decode(FHIRObservation.self) {
            self = .observation(obs)
        } else if let pat = try? container.decode(FHIRPatient.self) {
            self = .patient(pat)
        } else if let comp = try? container.decode(FHIRComposition.self) {
            self = .composition(comp)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown FHIR Resource Type")
        }
    }
}

public struct FHIRObservation: Codable {
    public var resourceType: String = "Observation"
    public let id: String
    public let meta: FHIRMeta?
    public let status: String
    public let category: [FHIRCodeableConcept]?
    public let code: FHIRCodeableConcept
    public let subject: FHIRReference
    public let effectiveDateTime: String
    public let valueQuantity: FHIRQuantity?
    public let valueString: String?
    public let referenceRange: [FHIRReferenceRange]?
    
    public init(id: String = UUID().uuidString, status: String = "final", category: [FHIRCodeableConcept]? = nil, code: FHIRCodeableConcept, subject: FHIRReference = FHIRReference(reference: "Patient/unknown"), effectiveDateTime: String, valueQuantity: FHIRQuantity?, valueString: String? = nil, referenceRange: [FHIRReferenceRange]? = nil) {
        self.id = id
        // Iniezione Profilo IPS
        self.meta = FHIRMeta(profile: ["http://hl7.org/fhir/uv/ips/StructureDefinition/Observation-uv-ips"])
        self.status = status
        self.category = category
        self.code = code
        self.subject = subject
        self.effectiveDateTime = effectiveDateTime
        self.valueQuantity = valueQuantity
        self.valueString = valueString
        self.referenceRange = referenceRange
    }
}

public struct FHIRPatient: Codable {
    public var resourceType: String = "Patient"
    public let id: String
    public let meta: FHIRMeta?
    public let identifier: [FHIRIdentifier]?
    public let name: [FHIRHumanName]?
    public let gender: String?
    public let birthDate: String?
    
    public init(id: String, identifier: [FHIRIdentifier]?, name: [FHIRHumanName]?, gender: String?, birthDate: String?) {
        self.id = id
        // Iniezione Profilo IPS
        self.meta = FHIRMeta(profile: ["http://hl7.org/fhir/uv/ips/StructureDefinition/Patient-uv-ips"])
        self.identifier = identifier
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
    }
}


public struct FHIRNarrative: Codable {
    public let status: String
    public let div: String
    public init(status: String = "generated", div: String) {
        self.status = status
        self.div = div
    }
}

public struct FHIRComposition: Codable {
    public var resourceType: String = "Composition"
    public let id: String
    public let meta: FHIRMeta?
    public var status: String = "final"
    public let type: FHIRCodeableConcept
    public let subject: FHIRReference
    public let date: String
    public let title: String
    public let text: FHIRNarrative?
    
    public init(id: String, type: FHIRCodeableConcept, subject: FHIRReference, date: String, title: String, text: FHIRNarrative? = nil) {
        self.id = id
        // Iniezione Profilo IPS
        self.meta = FHIRMeta(profile: ["http://hl7.org/fhir/uv/ips/StructureDefinition/Composition-uv-ips"])
        self.type = type
        self.subject = subject
        self.date = date
        self.title = title
        self.text = text
    }
}

public struct FHIRCodeableConcept: Codable {
    public let coding: [FHIRCoding]
    public let text: String?
    public init(coding: [FHIRCoding], text: String? = nil) {
        self.coding = coding
        self.text = text
    }
}

public struct FHIRCoding: Codable {
    public let system: String
    public let code: String
    public let display: String?
    public init(system: String, code: String, display: String? = nil) {
        self.system = system
        self.code = code
        self.display = display
    }
}

public struct FHIRQuantity: Codable {
    public let value: Double
    public let unit: String
    public let system: String
    public let code: String
    public init(value: Double, unit: String, system: String = "http://unitsofmeasure.org", code: String) {
        self.value = value
        self.unit = unit
        self.system = system
        self.code = code
    }
}

public struct FHIRReferenceRange: Codable {
    public let low: FHIRSimpleQuantity?
    public let high: FHIRSimpleQuantity?
    public let text: String?
}

public struct FHIRSimpleQuantity: Codable {
    public let value: Double
    public let unit: String
}

public struct FHIRReference: Codable {
    public let reference: String
    public let display: String?
    public init(reference: String, display: String? = nil) {
        self.reference = reference
        self.display = display
    }
}

public struct FHIRIdentifier: Codable {
    public let system: String
    public let value: String
    
    public init(system: String, value: String) {
        self.system = system
        self.value = value
    }
}

public struct FHIRHumanName: Codable {
    public let family: String?
    public let given: [String]?
}
