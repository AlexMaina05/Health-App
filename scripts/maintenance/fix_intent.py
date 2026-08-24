import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/Intents/ProcessReportIntent.swift', 'r', 'utf-8') as f:
    text = f.read()

target1 = """            guard let loinc = obs.code.coding.first?.code,
                  let hkType = bridge.mapLOINCToHKTypeIdentifier(loinc: loinc),
                  let value = obs.valueQuantity?.value else {
                continue
            }
            
            let date = obs.effectiveTime?.value ?? Date()
            
            let metricTarget = MetricTarget(type: hkType, defaultUnit: HKUnit(from: obs.valueQuantity?.unit ?? ""))"""
rep1 = """            guard let loinc = obs.code.coding.first?.code,
                  let metricTarget = bridge.loincToHKMap[loinc],
                  let value = obs.valueQuantity?.value else {
                continue
            }
            
            let date = Date()"""
text = text.replace(target1, rep1)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/Intents/ProcessReportIntent.swift', 'w', 'utf-8') as f:
    f.write(text)