import codecs
import re

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'r', 'utf-8') as f:
    text = f.read()

# Fix syntax error completely using regex
text = re.sub(r'let bundle = if #available\(iOS 16\.1, \*\) \{ self\.updateLiveActivity.*?\}\s*try transcoder\.transcode\(cdaData: xmlData\)', 
              'if #available(iOS 16.1, *) { self.updateLiveActivity(status: "Transcodifica in FHIR...", progress: 0) }\n                        let bundle = try transcoder.transcode(cdaData: xmlData)', 
              text, flags=re.DOTALL)

with codecs.open('e:/Code/Health-App/Sources/RosettaHealthApp/AppViewModel.swift', 'w', 'utf-8') as f:
    f.write(text)