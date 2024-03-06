import Foundation
import Combine

class LinkFileParser {
    private let linkFileInfo: LinkFileAnalyzeInfo
    private let onTargetContentParsed: (() -> Void)?
    
    private let parseContext: LinkFileParseContext
    private let sequentialWorkFlow: SequentialWorkFlow<LinkFileParseContext>
    
    private lazy var mainParseQeue: DispatchQueue = {
        return DispatchQueue(label: "parse_main_\(self.linkFileInfo.linkFileName)_\(currentNanoTimestamp())");
    }()
    
    private var i = 0
    
    init(_ linkFileInfo: LinkFileAnalyzeInfo, onTargetContentParsed: (() -> Void)?) {
        self.linkFileInfo = linkFileInfo
        self.onTargetContentParsed = onTargetContentParsed
        
        let objectFilePathFilter = ObjectFilePathFilter(linkFileInfo: linkFileInfo)
        self.parseContext = LinkFileParseContext(linkFileInfo: linkFileInfo, objectFilePathFilter: objectFilePathFilter)
        self.sequentialWorkFlow = SequentialWorkFlow(
            phases: [
                PrefixPhase(),
                ObjectFileParsePhase(),
                SectionPhase(),
                SymbolPhase(),
                DeadStrippedSymbolPhase(),
            ],
            context: self.parseContext
        )
    }
    
    func parse(_ lines: [String]) {
        self.mainParseQeue.async {
            self.parseImpl(lines)
        }
    }
    
    
    func waitParseResult() async -> Index2ObjDetailMap {
        return await withCheckedContinuation { continuation in
            self.mainParseQeue.async {
                if (!self.parseContext.runningContext.isLineCompleted) {
                    self.parseContext.runningContext.lineSubject.send(completion: .finished)
                }
                
                let index2ObjDetailMap = self.parseContext.runningContext.index2ObjDetailMap
                continuation.resume(returning: index2ObjDetailMap)
            }
        }
    }
    
    private func parseImpl(_ lines: [String]) {
        if (self.parseContext.isTargetContentParsed) {
            return
        }
        
        guard !lines.isEmpty else {
            return
        }
        
        for line in lines {
            self.i += 1
            if (self.i % 1000 == 0) {
                debugLog("parsing: \(line)")
            }
            
            if (!self.sequentialWorkFlow.isStarted) {
                self.parseContext.runningContext = RunningContext(lineNotifier: CurrentValueSubject<String, Never>(line))
                self.sequentialWorkFlow.start()
                continue
            }
            
            if (self.parseContext.isTargetContentParsed) {
                break
            }
            
            self.parseContext.runningContext.lineSubject.send(line)
        }
        
        if (self.parseContext.isTargetContentParsed) {
            self.onTargetContentParsed?()
        }
    }
}
