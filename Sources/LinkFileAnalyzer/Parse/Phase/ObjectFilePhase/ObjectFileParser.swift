import Foundation

class ObjectFileParser : ConcurrentParser {
    private let context: LinkFileParseContext
    private let linkFileName: String
    
    private lazy var objectFileMainQueue: DispatchQueue = {
        let linkFileName = self.context.linkFileInfo.linkFileName
        let queue = DispatchQueue(label: "parse_object_main_\(linkFileName)_\(currentNanoTimestamp())");
        return queue
    }()
    
    init(context: LinkFileParseContext) {
        self.context = context
        self.linkFileName = self.context.linkFileInfo.linkFileName
        
        super.init(
            dispatchQueueLabel: "parse_object_concurrent_\(self.linkFileName)_\(currentNanoTimestamp())",
            maxLineCountInOneTask: 10,
            maxConcurrencyCount: 10
        )
    }
    
    override func consumeLines(_ lines: [String], _ waitTaskGroup: DispatchGroup) {
        // [  1] A/B_lib.a(AppDelegate.o)
        // [  2] C/D_lib.a(AppDelegate.o)
        var resultMap = Index2ObjDetailMap()
        
        for line in lines {
            let userTags = self.context.objectFilePathFilter.filterTagsFrom(line)
            if userTags.isEmpty {
                continue
            }

            let elements = line.split(separator: "] ", maxSplits: 1);

            guard elements.count == 2 else {
                assert(false)
                continue
            }

            guard let index = Int(elements[0].dropFirst().trimmingCharacters(in: .whitespaces)) else {
                assert(false)
                continue
            }

            let objectFilePath = String(elements[1])
            
            var objectFileName = self.extractLastParenthesesContent(objectFilePath)
            if (objectFileName == nil) {
                objectFileName = URL(fileURLWithPath: objectFilePath).lastPathComponent
            }
            
            resultMap[index] = ObjDetail(objFilePath: objectFilePath, userTags: userTags, objectFileName: objectFileName ?? "")
        }
        
        if (resultMap.isEmpty) {
            return
        }
        
        waitTaskGroup.enter()
        self.objectFileMainQueue.async {
            self.saveResult(resultMap)
            waitTaskGroup.leave()
        }
        
    }
    
    private func saveResult(_ index2ObjDetailMap: Index2ObjDetailMap) {
        self.context.runningContext.index2ObjDetailMap = self.context.runningContext.index2ObjDetailMap.merging(index2ObjDetailMap) { (_, new) in new }
    }
    
    
    private func extractLastParenthesesContent(_ inputString: String) -> String? {
        guard let lastLeftParenthesisRange = inputString.range(of: "(", options: .backwards) else {
            return nil
        }
        
        let rangeAfterLastLeftParenthesis = lastLeftParenthesisRange.upperBound..<inputString.endIndex
        
        guard let lastRightParenthesisRange = inputString.range(of: ")", options: .literal, range: rangeAfterLastLeftParenthesis) else {
            return nil
        }
        
        let contentRange = lastLeftParenthesisRange.upperBound..<lastRightParenthesisRange.lowerBound
        let content = String(inputString[contentRange])
        
        return content
    }
}
