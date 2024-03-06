import Foundation
import Combine

class DeadStrippedSymbolPhase : WorkPhase<LinkFileParseContext> {
    private var subscription: AnyCancellable?
    private var parser: DeadStrippedSymbolParser?
    
    override func onEnter(context: LinkFileParseContext) {
        self.parser = DeadStrippedSymbolParser(context: context)
        
        //        # Dead Stripped Symbols:
        //        #            Size        File  Name
        
        // skip first two line
        subscription = context.runningContext.lineSubject.dropFirst(2).sink { completion in
            self.onLineCompleted()
        } receiveValue: { line in
            self.handleLine(line)
        }
    }
    
    override func onLeave(context: LinkFileParseContext) {
        self.subscription?.cancel()
        self.parser?.waitAllLinesHandled()
        
        context.isTargetContentParsed = true
    }
    
    override func shouldEnter(context: LinkFileParseContext) -> Bool {
        return context.runningContext.lineSubject.value == "# Dead Stripped Symbols:"
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
