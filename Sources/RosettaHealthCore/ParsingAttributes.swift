import ActivityKit
import Foundation

public struct ParsingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var processedFiles: Int
        public var totalFiles: Int
        public var statusText: String
        
        public init(processedFiles: Int, totalFiles: Int, statusText: String) {
            self.processedFiles = processedFiles
            self.totalFiles = totalFiles
            self.statusText = statusText
        }
    }
    
    public var batchName: String
    
    public init(batchName: String) {
        self.batchName = batchName
    }
}
