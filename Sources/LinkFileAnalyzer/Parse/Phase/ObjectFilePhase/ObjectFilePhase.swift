import Foundation
import Combine



class ObjectFileParsePhase : WorkPhase<LinkFileParseContext> {
    
    private var subscription: AnyCancellable?
    
    private var parser: ObjectFileParser?
    
    
    override func onEnter(context: LinkFileParseContext) {
        self.parser = ObjectFileParser(context: context)
        
        // # Object files:
        // skip first line
        subscription = getContext().runningContext.lineSubject.dropFirst().sink { completion in
            self.onLineCompleted()
        } receiveValue: { line in
            self.handleLine(line)
        }
    }
    
    override func onLeave(context: LinkFileParseContext) {
        self.subscription?.cancel()
        self.parser?.waitAllLinesHandled()
    }
    
    override func shouldEnter(context: LinkFileParseContext) -> Bool {
        return context.runningContext.lineSubject.value == "# Object files:"
    }
    
    private func handleLine(_ line: String) {
        if (super.shouldEnterNextPhase()) {
            super.enterNextPhase()
            return
        }
        
        self.parser?.handleLine(line)
    }
    
    private func onLineCompleted() {
        self.parser?.waitAllLinesHandled()
    }
}
