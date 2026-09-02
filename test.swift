import Foundation
class TestParser: NSObject, XMLParserDelegate {
    var text = ""
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let cleanStr = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanStr.isEmpty {
            text += cleanStr + " "
        }
    }
}
let xml = ""
<text>
    Paziente di 36 anni, asintomatico per angor o dispnea da sforzo.
    Riferisce sporadiche palpitazioni a riposo correlate a periodi di stress lavorativo.
    Non familiarità per cardiopatia ischemica precoce.
</text>
""
let parser = XMLParser(data: xml.data(using: .utf8)!)
let delegate = TestParser()
parser.delegate = delegate
parser.parse()
print("Text is: \n\(delegate.text)")
