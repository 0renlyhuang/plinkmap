import Foundation
import Combine

class PrefixPhase : WorkPhase<LinkFileParseContext> {
    
    private var subscription: AnyCancellable?
    
    override func onEnter(context: LinkFileParseContext) {
        self.subscription = context.runningContext.lineSubject.sink { line in
            self.handleLine(line)
        }
    }
    
    override func onLeave(context: LinkFileParseContext) {
        self.subscription?.cancel()
    }
    
    override func shouldEnter(context: LinkFileParseContext) -> Bool {
        return true
    }
    
    private func handleLine(_ line: String) {
        if (line.isEmpty || line == "\n") {
            return;
        }
        
        if (super.shouldEnterNextPhase()) {
            super.enterNextPhase()
            return
        }
    }
}
