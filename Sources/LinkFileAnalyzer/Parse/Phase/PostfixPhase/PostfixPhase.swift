import Foundation

import Foundation
import Combine

class PostfixPhase : WorkPhase<LinkFileParseContext> {
    
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
        return context.runningContext.lineSubject.value == ""
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
