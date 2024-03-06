import Foundation


class ConcurrentParser {
    private let dispatchQueueLabel: String
    private let maxLineCountInOneTask: Int
    private let maxConcurrencyCount: Int
    private let isNewLine: ((String) -> Bool)?
    
    private var linesToSubmit = [String]()
    
    private lazy var dispatchQueue: DispatchQueue = {
        let queue = DispatchQueue(label: self.dispatchQueueLabel, attributes: .concurrent);
        return queue
    }()
    
    private lazy var operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.dispatchQueue
        operationQueue.maxConcurrentOperationCount = self.maxConcurrencyCount
        
        return operationQueue
    }()
    
    private lazy var waitTaskGroup: DispatchGroup = {
        return DispatchGroup()
    }()
    
    
    init(dispatchQueueLabel: String, maxLineCountInOneTask: Int, maxConcurrencyCount: Int, isNewLine: ((String) -> Bool)? = nil) {
        self.dispatchQueueLabel = dispatchQueueLabel
        self.maxLineCountInOneTask = maxLineCountInOneTask
        self.maxConcurrencyCount = maxConcurrencyCount
        self.isNewLine = isNewLine
    }
    
    func handleLine(_ line: String) {
        if let isNewLine = self.isNewLine {
            if (isNewLine(line)) {
                if (linesToSubmit.count >= self.maxLineCountInOneTask) {  // collecting lines for one task
                    self.submitLines()
                }
            }
            
            linesToSubmit.append(line)
            return
        }
        
        
        linesToSubmit.append(line)
        if (linesToSubmit.count >= self.maxLineCountInOneTask) {  // collecting lines for one task
            self.submitLines()
        }
    }
    
    func waitAllLinesHandled() {
        if (!self.linesToSubmit.isEmpty) {
            self.submitLines()
        }
        
        
        self.waitTaskGroup.wait()
    }
    
    func consumeLines(_ lines: [String], _ waitTaskGroup: DispatchGroup) {
        fatalError("Subclasses must override consumeLines")
    }
    
    private func submitLines() {
        let lines = self.linesToSubmit
        self.linesToSubmit.removeAll()
        
        self.waitTaskGroup.enter()
        self.operationQueue.addOperation {
            self.consumeLines(lines, self.waitTaskGroup)
            self.waitTaskGroup.leave()
        }
    }
}
