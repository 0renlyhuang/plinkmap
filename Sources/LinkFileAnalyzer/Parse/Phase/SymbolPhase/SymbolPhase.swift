import Foundation
import Combine

class SymbolPhase : WorkPhase<LinkFileParseContext> {
    private var subscription: AnyCancellable?
    private var parser: SymbolParser?
    
    override func onEnter(context: LinkFileParseContext) {
        self.parser = SymbolParser(context: context)
        
        // # Symbols:
        // # Address    Size        File  Name
        
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
    }
    
    override func shouldEnter(context: LinkFileParseContext) -> Bool {
        return context.runningContext.lineSubject.value == "# Symbols:"
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

