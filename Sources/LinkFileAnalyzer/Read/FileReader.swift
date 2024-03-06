import Foundation

class FileReader {
    private let linkFileInfo: LinkFileAnalyzeInfo
    private let queue: DispatchQueue
    private var stopSemaphore = DispatchSemaphore(value: 0)
    
    init(_ linkFileInfo: LinkFileAnalyzeInfo) {
        self.linkFileInfo = linkFileInfo
        self.queue = DispatchQueue(label: "read_\(linkFileInfo.linkFileName)_\(currentNanoTimestamp())");
    }
    
    func read(onLineBlock: @escaping ([String]) -> Void) async {
        let filePath = self.linkFileInfo.linkFilePath
        
        do {
            try await self.read(filePath, onLineBlock)
        }
        catch {
            debugLog("\(error)")
        }
    }
    
    func stopRead() {
        self.stopSemaphore.signal()
    }
    
    private func read(_ filePath: String, _ onLineBlock: @escaping ([String]) -> Void) async throws {
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: filePath))
         defer {
             fileHandle.closeFile()
         }
        
        var linesTrunk = [String]()
        for try await line in fileHandle.bytes.lines {
            linesTrunk.append(line)
            if linesTrunk.count >= 1000 {
                onLineBlock(linesTrunk)
                linesTrunk.removeAll(keepingCapacity: true)
            }
        }
        
        if (!linesTrunk.isEmpty) {
            onLineBlock(linesTrunk)
        }
    }
}
