import codecs

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/ParsingAttributes.swift', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('import ActivityKit\nimport Foundation\n\npublic struct ParsingAttributes: ActivityAttributes {', '#if canImport(ActivityKit)\nimport ActivityKit\n#endif\nimport Foundation\n\n#if canImport(ActivityKit)\npublic struct ParsingAttributes: ActivityAttributes {')
text = text.replace('        public var progress: Double\n    }\n}', '        public var progress: Double\n    }\n}\n#endif')

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthCore/ParsingAttributes.swift', 'w', 'utf-8') as f:
    f.write(text)