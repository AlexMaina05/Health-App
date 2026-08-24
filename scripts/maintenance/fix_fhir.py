import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/FHIRModels.swift', 'r', 'utf-8') as f:
    text = f.read()

target1 = """public struct FHIRReferenceRange: Codable {
    public let low: FHIRQuantity?
    public let high: FHIRQuantity?
}"""
rep1 = """public struct FHIRReferenceRange: Codable {
    public let low: FHIRQuantity?
    public let high: FHIRQuantity?
    
    public init(low: FHIRQuantity?, high: FHIRQuantity?) {
        self.low = low
        self.high = high
    }
}"""
text = text.replace(target1, rep1)

target2 = """public struct FHIRQuantity: Codable {
    public let value: Double
    public let unit: String
    public let system: String
    public let code: String
}"""
rep2 = """public struct FHIRQuantity: Codable {
    public let value: Double
    public let unit: String
    public let system: String
    public let code: String
    
    public init(value: Double, unit: String, system: String, code: String) {
        self.value = value
        self.unit = unit
        self.system = system
        self.code = code
    }
}"""
text = text.replace(target2, rep2)

target3 = """public struct FHIRIdentifier: Codable {
    public let system: String
    public let value: String
}"""
rep3 = """public struct FHIRIdentifier: Codable {
    public let system: String
    public let value: String
    
    public init(system: String, value: String) {
        self.system = system
        self.value = value
    }
}"""
text = text.replace(target3, rep3)

target4 = """public struct FHIRHumanName: Codable {
    public let use: String?
    public let family: String?
    public let given: [String]?
}"""
rep4 = """public struct FHIRHumanName: Codable {
    public let use: String?
    public let family: String?
    public let given: [String]?
    
    public init(use: String?, family: String?, given: [String]?) {
        self.use = use
        self.family = family
        self.given = given
    }
}"""
text = text.replace(target4, rep4)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/FHIRModels.swift', 'w', 'utf-8') as f:
    f.write(text)