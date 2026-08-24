import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/HealthKitBridge.swift', 'r', 'utf-8') as f:
    text = f.read()

target = 'let hkQuantity = HKQuantity(unit: metricTarget.defaultUnit, doubleValue: value)'
rep = 'var finalValue = value\n            if metricTarget.type == .oxygenSaturation && finalValue > 1.0 {\n                finalValue = finalValue / 100.0\n            }\n            let hkQuantity = HKQuantity(unit: metricTarget.defaultUnit, doubleValue: finalValue)'

text = text.replace(target, rep)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/HealthKitBridge.swift', 'w', 'utf-8') as f:
    f.write(text)