import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/ClinicalDecisionSupport.swift', 'r', 'utf-8') as f:
    text = f.read()

target = """        let chronologicalSamples = samples.sorted(by: { $0.startDate < $1.startDate })
        
        let v1 = chronologicalSamples[0].quantity.doubleValue(for: chronologicalSamples[0].quantityType.isCompatible(with: HKUnit(from: "mg/dL")) ? HKUnit(from: "mg/dL") : HKUnit.count()) // Semplificazione unità
        let v2 = chronologicalSamples[1].quantity.doubleValue(for: chronologicalSamples[0].quantity.is(compatibleWith: HKUnit(from: "mg/dL")) ? HKUnit(from: "mg/dL") : HKUnit.count()) // Correzione sintassi
        let v3 = chronologicalSamples[2].quantity.doubleValue(for: chronologicalSamples[0].quantity.is(compatibleWith: HKUnit(from: "mg/dL")) ? HKUnit(from: "mg/dL") : HKUnit.count())
        
        // Calcolo pendenza
        let delta = (v3 - v1) / v1"""

rep = """        let recentSamples = Array(samples.sorted(by: { $0.startDate < $1.startDate }).suffix(3))
        
        let unit = recentSamples[0].quantity.is(compatibleWith: HKUnit(from: "mg/dL")) ? HKUnit(from: "mg/dL") : HKUnit.count()
        let v1 = recentSamples[0].quantity.doubleValue(for: unit)
        let v2 = recentSamples[1].quantity.doubleValue(for: unit)
        let v3 = recentSamples[2].quantity.doubleValue(for: unit)
        
        // Calcolo pendenza
        let delta = v1 != 0 ? (v3 - v1) / v1 : 0.0"""
text = text.replace(target, rep)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/ClinicalDecisionSupport.swift', 'w', 'utf-8') as f:
    f.write(text)